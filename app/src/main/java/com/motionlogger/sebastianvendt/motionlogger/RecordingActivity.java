package com.motionlogger.sebastianvendt.motionlogger;

import android.content.Context;
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
ACC-X | ACC-Y | ACC-Z | GYR-X | GYR-Y | GYR-Z | TOUCH (0/1) | LOC-X | LOC-Y
This allows a postprocessing with matlab to cut the windows of the touch events and also allows for data augmentation later on
windows of fixed size will be extracted
-> check how long most touch events last since we have a fixed window size
shows a heatmap of the touches within the last session, shows a counter
has a button to end the record, to pause it and to resume it

 */

public class RecordingActivity extends AppCompatActivity implements SensorEventListener, View.OnTouchListener {

    static final int SENSORDELAY = SensorManager.SENSOR_DELAY_GAME;

    private File recordFolder;
    private File recordFile;
    private File path;
    private BufferedOutputStream buffer;
    private FileOutputStream filestream;

    private SensorManager sManLACC;
    private Sensor sensorLACC;
    private SensorManager sManGYRO;
    private Sensor sensorGYRO;

    private float[] gyroscope = new float[3];
    private long timediffGyro;

    private float[] accelerometer = new float[3];
    private long timediffACC;

    private long timestampGyro;
    private long timestampAcc;
    private long eventcounter;

    private int[] touchCoordinates = new int[2];
    private int touch;
    private int touchCounter;




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
        initFileStream(dateFormat.format(date));
        //set the textfield to the appropriate filename
        TextView textViewFileName = (TextView) findViewById(R.id.fileName);
        textViewFileName.setText(dateFormat.format(date));

        textViewTapCounter = (TextView) findViewById(R.id.tapCounter);

        initSensor();
        eventcounter = 0;
        touchCounter = 0;
        touch = 0;

        //create fileheader
        writeBuffer("GYRO_DIFF, GYRO_X, GYRO_Y, GYRO_Z, ACC_DIFF, ACC_X, ACC_Y, ACC_Z, TOUCH_DOWN, TOUCH_X, TOUCH_Y \n");
    }

    @Override
    protected void onDestroy() {
        //called when the recording is finished
        super.onDestroy();
        closeFileStream();
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
            accelerometer[0] = event.values[0];
            accelerometer[1] = event.values[1];
            accelerometer[2] = event.values[2];
            timediffACC = event.timestamp - timestampAcc;
            timestampAcc = event.timestamp;
            //Log.d("INFO", "ACC: " + diffACC + " " + accX + ", " + accY + ", " + accZ);
        } else if (event.sensor.getType() == Sensor.TYPE_GYROSCOPE) {
            gyroscope[0] = event.values[0];
            gyroscope[1] = event.values[1];
            gyroscope[2] = event.values[2];
            timediffGyro = event.timestamp - timestampGyro;
            timestampGyro = event.timestamp;
            //Log.d("INFO", "GYR: " + diffGyro + " " + gyrX + ", " + gyrY + ", " + gyrZ);
        }
        if (eventcounter % 2 == 0) {
            //write to stream
            writeBuffer(timediffGyro + ", " + gyroscope[0] + ", " + gyroscope[1] + ", " + gyroscope[2] + ", " +
                    timediffACC + ", " + accelerometer[0] + ", " + accelerometer[1] + ", " + accelerometer[2] + ", " + touch + ", " + touchCoordinates[0] + ", " + touchCoordinates[1] + "\n");
        }
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {

    }

    @Override
    public boolean onTouch(View v, MotionEvent event) {
        int maskedAction = event.getActionMasked();
        int actionIndex = event.getActionIndex();
        if(recActive) {
            if (maskedAction == MotionEvent.ACTION_DOWN || maskedAction == MotionEvent.ACTION_POINTER_DOWN) {
                touch = 1;
                touchCounter += 1;
                touchCoordinates[0] = (int) event.getX(actionIndex);
                touchCoordinates[1] = (int) event.getY(actionIndex);
                textViewTapCounter.setText("" + touchCounter);
                Log.d("TAG", "X " + touchCoordinates[0] + " Y " + touchCoordinates[1] + " " + touch);
            } else if (maskedAction == MotionEvent.ACTION_UP) { //ACTION_UP gets fired when the final pointer is released
                touch = 0;
                touchCoordinates[0] = 0;
                touchCoordinates[1] = 0;
            } else if (maskedAction == MotionEvent.ACTION_MOVE || maskedAction == MotionEvent.ACTION_POINTER_UP) {
                //TODO find appropriate handling of this event
            } else {
                Log.e("ERROR", "Encountered unknown touch event " + maskedAction);
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
        }
    }

    private void initSensor() {
        sManLACC = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        if (sManLACC.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION) != null) {
            sensorLACC = sManLACC.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION);
        } else {
            Log.e("ERROR", "Initializing linear accelerometer failed, could not get sensor");
        }
        Log.d("INIT", "sucessfully initialized linear Acceleration sensor");

        sManGYRO = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        if (sManGYRO.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null) {
            sensorGYRO = sManGYRO.getDefaultSensor(Sensor.TYPE_GYROSCOPE);
        } else {
            Log.e("ERROR", "Initializing gyroscope failed, could not get sensor");
        }
        Log.d("INIT", "sucessfully initialized Gyroscope sensor");
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
        Log.d("INFO", "stop logging");
        sManLACC.unregisterListener(this);
        sManGYRO.unregisterListener(this);
        recActive = false;
        //return to the main activity and clean up
        finish();
    }

    private void writeBuffer(String string) {
        try {
            buffer.write(string.getBytes());
        } catch (java.io.IOException e) {
            e.printStackTrace();
        }
    }

    private void closeFileStream() {
        Log.d("INFO", "closing Filestream");
        try {
            buffer.flush();
            filestream.close();
        } catch (java.io.IOException e) {
            e.printStackTrace();
        }
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
    private final int deltaColor = ;
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
            updateTapCounter(XY[0], XY[1]);
            //TODO the tapcounter needs to be set to 1 within the whole kernel to effectivly get a heatmap

            //Bitmap canvasBitmap = Bitmap.createBitmap(heatmap, offset, offset, width, height);
            if (surfaceHolder.getSurface().isValid()) {
                Canvas canvas = surfaceHolder.lockCanvas();
                canvas.drawBitmap(heatmap, new Rect(offset, offset, width + offset, height + offset), new Rect(offset, offset, width + offset, height + offset), null);
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

    private void updateTapCounter(int x, int y) {
        for (int i = 0; i < kernelsize; i++) {
            for(int k = 0; k < kernelsize; k++){
                tapCounter[x - offset + i][y - offset + k] += 1;
            }
        }
    }

    private void updateHeatMap(int x, int y) {
        //int tapcount = tapCounter[x][y];
        int[] pixels = new int[kernelsize * kernelsize];
        //create entry in heatmap

        for (int i = 0; i < pixels.length; i++) {

        }

        int red = tapcount >= maxStep ? (int) (255 - deltaRGB[0]) : (int) (255 - deltaStepRGB[0] * tapcount);
        int green = tapcount >= maxStep ? (int) (255 - deltaRGB[1]) : (int) (255 - deltaStepRGB[1] * tapcount);
        int blue = tapcount >= maxStep ? (int) (255 - deltaRGB[2]) : (int) (255 - deltaStepRGB[2] * tapcount);
        int color = getColor(red, green, blue, 255);

        Arrays.fill(pixels, color);
        try {
            heatmap.setPixels(pixels, 0, kernelsize, XY[0] - offset, XY[1] - offset, kernelsize, kernelsize);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
