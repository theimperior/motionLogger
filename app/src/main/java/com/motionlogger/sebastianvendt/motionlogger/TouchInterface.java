package com.motionlogger.sebastianvendt.motionlogger;

import android.os.Environment;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;

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

public class TouchInterface extends AppCompatActivity {

    private File recordFolder;
    private File recordFile;
    private FileWriter recordFileWriter;

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
        setContentView(R.layout.activity_touch_interface);
        findViewById(android.R.id.content).setOnTouchListener(handleTouch);

        //setup the File I/O
        /*recordFolder = getPublicAlbumStorageDir("MotionLogger");
        recordFile = new File(recordFolder, "recordA.txt");
        try {
            recordFileWriter = new FileWriter(recordFile);
        } catch (IOException e) {
            e.printStackTrace();
        }*/
        //Files storage directory is under Main Storage - Android - Data - com.motionlogger.sebastianvendt.motionlogger - files
        File path = this.getExternalFilesDir(null);
        recordFile = new File(path, "myFile.txt");
        FileOutputStream stream = null;
        try {
            stream = new FileOutputStream(recordFile);
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        }

        try {
            stream.write("test".getBytes());
            stream.close();
        } catch (java.io.IOException e) {
            e.printStackTrace();
        }

    }


    @Override
    protected void onDestroy() {
        try {
            recordFileWriter.flush();
            recordFileWriter.close();
        } catch (IOException e) {
            e.printStackTrace();
        }

    }

    public File getPublicAlbumStorageDir(String albumName) {

        File file = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM), albumName);

        if(!file.mkdirs()) {
            Log.e("TAG", "Directory not created");
        }
        return file;
    }
}
