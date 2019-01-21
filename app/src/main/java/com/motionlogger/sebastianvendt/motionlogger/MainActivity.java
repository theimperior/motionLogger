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

       /* if(console != null){
            console.append(message);
            final Layout layout = console.getLayout();
            if(layout != null){
                int scrollDelta = layout.getLineBottom(console.getLineCount() - 1)
                        - console.getScrollY() - console.getHeight();
                if(scrollDelta > 0)
                    console.scrollBy(0, scrollDelta);
            }
        }*/

        console.append(message);/*
        Layout consoleLayout = console.getLayout();
        if(consoleLayout != null) {
            final int scrollAmount = consoleLayout.getLineTop(console.getLineCount()) - console.getHeight();
            if(scrollAmount > 0) {
                console.scrollTo(0, scrollAmount);
            } else {
                console.scrollTo(0,0);
            }
        }*/
    }

    public void sendMessage(View view) {
       /* Intent intent = new Intent(this, DisplayMessageActivity.class);
        EditText editText = (EditText) findViewById(R.id.Console);
        String message = editText.getText().toString();
        intent.putExtra(EXTRA_MESSAGE, message);
        startActivity(intent);*/

    }


};
