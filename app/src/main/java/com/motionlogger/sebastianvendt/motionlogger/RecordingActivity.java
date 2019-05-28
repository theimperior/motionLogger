package com.motionlogger.sebastianvendt.motionlogger;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;

/*
The interface for the actual logging of sensor data while the user taps on the screen
shows the picture of a keyboard, logs the sensor data in all directions from the motion sensor and the gyroscope (maybe neglate one axis)
into a file with unique filename (year, month, day, time) +  taps in that session
output will be a column oriented csv file
GYRO_DIFF, GYRO_X, GYRO_Y, GYRO_Z, ACC_DIFF, ACC_X, ACC_Y, ACC_Z, TOUCH_DOWN, TOUCH_X, TOUCH_Y
This allows a postprocessing with matlab to cut the windows of the touch events and also allows for data augmentation later on
windows of fixed size will be extracted
-> check how long most touch events last since we have a fixed window size
shows a heatmap of the touches within the last session, shows a counter
has a button to end the record, to pause it and to resume it

 */

public class RecordingActivity extends AppCompatActivity implements SensorEventListener, View.OnTouchListener {

    static final int SENSORDELAY = SensorManager.SENSOR_DELAY_FASTEST;

    public static final String CONSOLE_MSG = "Empty";
    private String ConMessageBuffer = "";

    private File recordFolder;
    private File recordFile;
    private File path;
    private BufferedOutputStream buffer;
    private FileOutputStream filestream;

    private SensorManager sManLACC;
    private Sensor sensorLACC;
    private SensorManager sManGYRO;
    private Sensor sensorGYRO;

    private float[] gyroscopeXYZ = new float[3];
    private long timediffGyro;

    private float[] accelerometerXYZ = new float[3];
    private long timediffACC;

    private long timestampGyro;
    private long timestampAcc;
    private long eventcounter;

    private int[] touchCoordinates = {0, 0};
    private int touch;
    private int touchCounter;
    private int[] trackedID = {0, 0};
    private int moveActionCounter = 0;

    private boolean recActive = false;

    TextView textViewTapCounter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_recording);

        findViewById(android.R.id.content).setOnTouchListener(this);

        LinearLayout canvasSurface = (LinearLayout) findViewById(R.id.LinearLayoutCanvas);
        canvasSurface.addView(new TapMap(this));

        //setup the recording
        DateFormat dateFormat = new SimpleDateFormat("yyyy_MM_dd_HHmm");
        Date date = new Date();
        initFileStream(dateFormat.format(date) + ".csv");
        //set the textfield to the appropriate filename
        TextView textViewFileName = (TextView) findViewById(R.id.fileName);
        textViewFileName.setText(dateFormat.format(date));
        appendToMsgBuffer("saved to file: " + dateFormat.format((date)) + "\n");

        textViewTapCounter = (TextView) findViewById(R.id.tapCounter);

        initSensor();
        eventcounter = 0;
        touchCounter = 0;
        touch = 0;

        //create fileheader
        writeBuffer("GYRO_DIFF, GYRO_X, GYRO_Y, GYRO_Z, ACC_DIFF, ACC_X, ACC_Y, ACC_Z, TOUCH_DOWN, TOUCH_X, TOUCH_Y, ID1, ID2 \n");
    }

    @Override
    protected void onDestroy() {
        //called when the recording is finished
        super.onDestroy();
        Log.d("INFO", "stop logging");
        sManLACC.unregisterListener(this);
        sManGYRO.unregisterListener(this);
        recActive = false;

        //return to the main activity and clean up
        //create new Intent for console message

        appendToMsgBuffer("Statistics of the last recording:");
        appendToMsgBuffer(touchCounter + " touch events");
        appendToMsgBuffer(eventcounter + " sensor events");
        appendToMsgBuffer(moveActionCounter + " moveAction events");
        closeFileStream();
        final Intent data = new Intent();
        data.putExtra(CONSOLE_MSG, "test");
        //TODO probably the setresult should be called before finish!
        setResult(Activity.RESULT_OK, data);
    }


    /*
        storing both events in separate variables
        has a counter and after every two events both get written into the output file
     */
    @Override
    public final void onSensorChanged(SensorEvent event) {
        eventcounter += 1;
        if (eventcounter % 50 == 0) {
            Log.d("INFO", eventcounter + " events");
        }
        if (event.sensor.getType() == Sensor.TYPE_LINEAR_ACCELERATION) {
            accelerometerXYZ[0] = event.values[0];
            accelerometerXYZ[1] = event.values[1];
            accelerometerXYZ[2] = event.values[2];
            timediffACC = event.timestamp - timestampAcc;
            timestampAcc = event.timestamp;
            //Log.d("INFO", "ACC: " + diffACC + " " + accX + ", " + accY + ", " + accZ);
        } else if (event.sensor.getType() == Sensor.TYPE_GYROSCOPE) {
            gyroscopeXYZ[0] = event.values[0];
            gyroscopeXYZ[1] = event.values[1];
            gyroscopeXYZ[2] = event.values[2];
            timediffGyro = event.timestamp - timestampGyro;
            timestampGyro = event.timestamp;
            //Log.d("INFO", "GYR: " + diffGyro + " " + gyrX + ", " + gyrY + ", " + gyrZ);
        }
        if (eventcounter % 2 == 0) {
            //write to stream
            writeBuffer(timediffGyro + ", " + gyroscopeXYZ[0] + ", " + gyroscopeXYZ[1] + ", " + gyroscopeXYZ[2] + ", " +
                    timediffACC + ", " + accelerometerXYZ[0] + ", " + accelerometerXYZ[1] + ", " + accelerometerXYZ[2] + ", " +
                    touch + ", " + touchCoordinates[0] + ", " + touchCoordinates[1] +
                    trackedID[0] + ", " + trackedID[1] + "\n");
            touchCoordinates[0] = 0;
            touchCoordinates[1] = 0;
            touch = 0;
            trackedID[0] = 0;
            trackedID[1] = 0;
        }
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
        appendToMsgBuffer("Error - Accuracy of sensor " + sensor.getName() + "changed to " + accuracy);
        appendToMsgBuffer("End recording");
        finish();
    }

    @Override
    public boolean onTouch(View v, MotionEvent event) {
        int maskedAction = event.getActionMasked();
        int actionIndex = event.getActionIndex();
        int actionID = event.getPointerId(actionIndex);


        if(recActive) {
            if (maskedAction == MotionEvent.ACTION_DOWN || maskedAction == MotionEvent.ACTION_POINTER_DOWN) {
                touch = 1;
                touchCounter += 1;
                touchCoordinates[0] = (int) event.getX(actionIndex);
                touchCoordinates[1] = (int) event.getY(actionIndex);
                textViewTapCounter.setText("" + touchCounter);
                Log.d("TAG", "X " + touchCoordinates[0] + " Y " + touchCoordinates[1] + " " + touch);
                if(trackedID[0] != 0) {
                    if (trackedID[1] != 0) {
                        // no free space in the array -> something went wrong
                        Log.e("TAG", "Encountered third pointer ID while tracking two - too many fingers on the screen!!");
                        appendToMsgBuffer("ERROR - Encountered third pointer ID while tracking two - too many fingers on the screen!!");
                        finish();
                    } else {
                        trackedID[1] = actionID;
                    }
                } else {
                    trackedID[0] = actionID;
                }
           } else if (maskedAction == MotionEvent.ACTION_UP || maskedAction == MotionEvent.ACTION_POINTER_UP) { //ACTION_UP gets fired when the final pointer is released
                //find the actionID and remove it
                if(trackedID[0] == actionID) {
                    trackedID[0] = 0;
                } else if(trackedID[1] == actionID){
                    trackedID[1] = 0;
                } else {
                    Log.e("ERROR", "Could not find action ID among the tracked IDs, something went wrong here");
                    appendToMsgBuffer("ERROR - Could not find action ID among the tracked IDs");
                    finish();
                }
            } else if (maskedAction == MotionEvent.ACTION_MOVE || maskedAction == MotionEvent.ACTION_POINTER_UP) {
                moveActionCounter += 1;
            } else {
                Log.e("ERROR", "Encountered unknown touch event " + maskedAction);
                appendToMsgBuffer("ERROR - Unknown touch event");
                finish();
            }

        }
        return true;
    }

    private void initFileStream(String filename) {
        //Files storage directory is under Main Storage - Android - Data - com.motionlogger.sebastianvendt.motionlogger - files
        path = this.getExternalFilesDir(null);
        recordFile = new File(path, filename);
        filestream = null;
        try {
            filestream = new FileOutputStream(recordFile);
            buffer = new BufferedOutputStream(filestream);
        } catch (FileNotFoundException e) {
            e.printStackTrace();
            appendToMsgBuffer("ERROR - could not init file stream");
            finish();
        }
    }

    private void initSensor() {
        sManLACC = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        if (sManLACC.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION) != null) {
            sensorLACC = sManLACC.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION);
        } else {
            //TODO instead of logging to the logger, finish activity and log to the console!
            Log.e("ERROR", "Initializing linear accelerometer failed, could not get sensor");
        }
        Log.d("INIT", "successfully initialized linear Acceleration sensor");

        sManGYRO = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        if (sManGYRO.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null) {
            sensorGYRO = sManGYRO.getDefaultSensor(Sensor.TYPE_GYROSCOPE);
        } else {
            Log.e("ERROR", "Initializing gyroscope failed, could not get sensor");
        }
        Log.d("INIT", "successfully initialized Gyroscope sensor");
        Log.d("INFO", "Min Delay of ACC " + sensorLACC.getMinDelay());
        Log.d("INFO", "Min Delay of GYRO " + sensorGYRO.getMinDelay());
    }

    public void onPlay(View view) {
        Log.d("INFO", "start/resume logging");
        sManLACC.registerListener(this, sensorLACC, SENSORDELAY);
        try {
            Thread.sleep(20);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        sManGYRO.registerListener(this, sensorGYRO, SENSORDELAY);
        recActive = true;
    }

    public void onPausing(View view) {
        Log.d("INFO", "pause logging");
        sManLACC.unregisterListener(this);
        sManGYRO.unregisterListener(this);
        recActive = false;
    }

    public void stopRecording(View view) {
        finish();
    }

    private void writeBuffer(String string) {
        try {
            buffer.write(string.getBytes());
        } catch (java.io.IOException e) {
            e.printStackTrace();
            appendToMsgBuffer("Error writing buffer - see log for details");
            finish();
        }
    }

    private void closeFileStream() {
        Log.d("INFO", "closing filestream");
        try {
            buffer.flush();
            filestream.close();
        } catch (java.io.IOException e) {
            e.printStackTrace();
            appendToMsgBuffer("ERROR closing file stream - see log for details");
        }
    }

    private void appendToMsgBuffer(String msg) {
        ConMessageBuffer = ConMessageBuffer + msg + "\n";
    }
}

class TapMap extends SurfaceView {
    private final int kernelsize = 30;
    private final int width = 1080;
    private final int height = 980;
    private int mapWidth;
    private int mapHeight;
    private int offset = (int)Math.floor(kernelsize / 2);
    private final int deltaRGB[] = {226, 77, 255};
    private final double maxStep = 5;
    private final double deltaStepRGB[] = {deltaRGB[0] / maxStep, deltaRGB[1] / maxStep, deltaRGB[2] / maxStep};

    private final SurfaceHolder surfaceHolder;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private Bitmap heatmap;

    private int[][] tapCounter = new int[width + 2 * offset][height + 2 * offset];

    public TapMap(Context context) {
        super(context);
        surfaceHolder = getHolder();
        //paint.setColor(Color.RED);
        //paint.setStyle(Paint.Style.FILL);

        //Create Bitmap and fill with white
        mapWidth = width + 2 * offset;
        mapHeight = height + 2 * offset;
        heatmap = Bitmap.createBitmap(mapWidth, mapHeight, Bitmap.Config.ARGB_8888);
        heatmap.eraseColor(getColor((byte)255, (byte)255, (byte)255, (byte)255));
        //TODO set color of the canvas initially
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        int action = event.getActionMasked();
        int XY[] = {(int) event.getX(event.getActionIndex()), (int) event.getY(event.getActionIndex())};
        if(action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_POINTER_DOWN) {
            updateHeatmap(XY[0], XY[1]);
            //Bitmap canvasBitmap = Bitmap.createBitmap(heatmap, offset, offset, width, height);
            if (surfaceHolder.getSurface().isValid()) {
                Canvas canvas = surfaceHolder.lockCanvas();
                canvas.drawBitmap(heatmap, new Rect(offset, offset, width + offset, height + offset), new Rect(0, 0, width, height), null);
                //canvas.drawColor(Color.BLACK);
                //canvas.drawCircle(event.getX(), event.getY(), 50, paint);
                surfaceHolder.unlockCanvasAndPost(canvas);
            }
        }
        return false;
    }

    private int getColor (int r, int g, int b, int alpha) {
        return (alpha & 0xff) << 24 | (b & 0xff) << 16 | (g & 0xff) << 8 | (r & 0xff);
    }

    private void updateHeatmap(int x, int y) {
        for (int i = 0; i < kernelsize; i++) {
            for(int k = 0; k < kernelsize; k++){
                tapCounter[x - offset + i][y - offset + k] += 1;
                int tapcount = tapCounter[x - offset + i][y - offset + k];
                //color needs to be recalculated every time since we have integer arithmetics. Otherwise we could only add a deltacolor onto every pixel
                //within the kernel
                int red = tapcount >= maxStep ? (int) (255 - deltaRGB[0]) : (int) (255 - deltaStepRGB[0] * tapcount);
                int green = tapcount >= maxStep ? (int) (255 - deltaRGB[1]) : (int) (255 - deltaStepRGB[1] * tapcount);
                int blue = tapcount >= maxStep ? (int) (255 - deltaRGB[2]) : (int) (255 - deltaStepRGB[2] * tapcount);
                int color = getColor(red, green, blue, 255);
                try {
                    heatmap.setPixel(x-offset+i, y-offset+k, color);
                } catch (IllegalArgumentException e) {
                    e.printStackTrace();
                }
            }
        }
    }
}
