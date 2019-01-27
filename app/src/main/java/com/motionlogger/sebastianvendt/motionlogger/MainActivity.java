package com.motionlogger.sebastianvendt.motionlogger;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorManager;
import android.os.Environment;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.text.Layout;
import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;
import android.widget.EditText;
import android.content.Intent;
import android.widget.TextView;

import java.util.Iterator;
import java.util.List;


public class MainActivity extends AppCompatActivity {
    private SensorManager mSensorManager;
    private TextView console;

    private View.OnTouchListener handleTouch = new View.OnTouchListener() {

        public boolean onTouch(View v, MotionEvent event) {
            int x = (int) event.getX();
            int y = (int) event.getY();
            Log.d("TAG", "touched" + x + " " + y + " ");
            return true;
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        findViewById(android.R.id.content).setOnTouchListener(handleTouch);
        console = (TextView) findViewById(R.id.Console);
        console.setMovementMethod(new ScrollingMovementMethod());
        //Check the availability of the external storage
        addMessageToConsole("checking external storage permission\n");
        if(isExternalStorageWritable()){
            addMessageToConsole("external storage: write permission available!\n");
        } else {
            addMessageToConsole("ERROR: external storage write permission NOT available");
        }


    }

    public boolean isExternalStorageWritable() {
        String state = Environment.getExternalStorageState();
        if (Environment.MEDIA_MOUNTED.equals(state)) {
            return true;
        }
        return false;
    }

    public void readSensors(View view) {
        //list the sensors available on the device
        mSensorManager = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        List<Sensor> deviceSensors = mSensorManager.getSensorList(Sensor.TYPE_ALL);
        Iterator<Sensor> sensorIterator = deviceSensors.iterator();

        while (sensorIterator.hasNext()){
            Sensor sens = sensorIterator.next();
            addMessageToConsole(sens.getName() + "\n");
        }
    }

    public void addMessageToConsole(String message) {
        console.append(message);
    }

    public void recordTrainingData (View view) {
        Intent recTrainingData = new Intent(this, TouchInterface.class);
        startActivity(recTrainingData);
    }


};
