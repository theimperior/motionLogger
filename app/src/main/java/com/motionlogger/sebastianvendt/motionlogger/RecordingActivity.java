package com.motionlogger.sebastianvendt.motionlogger;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
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
        if (event.getAction() == MotionEvent.ACTION_DOWN) {
            touch = 1;
            touchCounter += 1;
            touchCoordinates[0] = (int) event.getX();
            touchCoordinates[1] = (int) event.getY();
            textViewTapCounter.setText("" + touchCounter);
        } else if (event.getAction() == MotionEvent.ACTION_UP) {
            touch = 0;
            touchCoordinates[0] = 0;
            touchCoordinates[1] = 0;
        } else {
            //do some error handling
        }
        //Log.d("TAG", "touched" + x + " " + y + " " + touch);
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
    }

    public void onPausing(View view) {
        Log.d("INFO", "pause logging");
        sManLACC.unregisterListener(this);
        sManGYRO.unregisterListener(this);
    }

    public void stopRecording(View view) {
        Log.d("INFO", "stop logging");
        sManLACC.unregisterListener(this);
        sManGYRO.unregisterListener(this);
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

    private final SurfaceHolder surfaceHolder;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);

    public TapMap(Context context) {
        super(context);
        surfaceHolder = getHolder();
        paint.setColor(Color.RED);
        paint.setStyle(Paint.Style.FILL);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if(event.getAction() == MotionEvent.ACTION_DOWN) {
            if (surfaceHolder.getSurface().isValid()) {
                Canvas canvas = surfaceHolder.lockCanvas();
                canvas.drawColor(Color.BLACK);
                canvas.drawCircle(event.getX(), event.getY(), 50, paint);
                surfaceHolder.unlockCanvasAndPost(canvas);
            }
        }
        return false;
    }
}
