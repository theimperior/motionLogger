package com.motionlogger.sebastianvendt.motionlogger;

import android.app.Activity;
import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorManager;
import android.os.Environment;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.text.method.ScrollingMovementMethod;
import android.view.View;
import android.content.Intent;
import android.widget.TextView;

import java.util.Iterator;
import java.util.List;

/*
Main activity to prepare the collection of sensor data
- checks permisions to write to the external storage
- checks if the sensors are available to read
- links to the activity to start the recording
- UI for the following settings:
 */

public class MainActivity extends Activity {
    private SensorManager mSensorManager;
    private TextView console;

    private static final int REQUEST_CODE = 0x19FF;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
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
            addMessageToConsole(sens.getName() + ", type: " + sens.getStringType() + "\n");
        }
    }

    public void addMessageToConsole(String message) {
        console.append(message);
    }

    public void recordTrainingData (View view) {
        Intent recTrainingData = new Intent(this, RecordingActivity.class);
        //startActivity(recTrainingData);
        startActivityForResult(recTrainingData, REQUEST_CODE);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        if(requestCode == REQUEST_CODE) {
            if(resultCode == Activity.RESULT_OK) {
                final String resultString = data.getStringExtra(RecordingActivity.CONSOLE_MSG);
                addMessageToConsole(resultString);
            }
        }
    }
};
