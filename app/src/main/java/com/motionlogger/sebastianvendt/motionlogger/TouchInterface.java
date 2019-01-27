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

        File path = this.getExternalFilesDir(null);
        recordFile = new File(path, "myFile.txt");
        FileOutputStream stream = null;
        try {
            stream = new FileOutputStream(recordFile);
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        }

        try {
            stream.write("texttextext".getBytes());
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
