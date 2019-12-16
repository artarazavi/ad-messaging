package com.example.chatlayout;

import android.app.Activity;
import android.database.DataSetObserver;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.widget.AbsListView;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.ListView;
import android.database.Cursor;
import android.widget.Toast;
import android.content.Context;
import android.os.Handler;
import android.util.Log;
import android.app.AlertDialog;

import android.annotation.SuppressLint;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.DialogInterface;
import android.content.Intent;
import android.graphics.Color;
import android.os.Build;
import android.support.v4.app.NotificationCompat;
import android.widget.Toast;
import android.view.LayoutInflater;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import java.io.IOException;

public class MainActivity extends Activity {
    DatabaseHelper myDb;
    UserHelper userDb;

    private ChatArrayAdapter chatArrayAdapter;
    private ListView listView;
    private EditText chatText;
    private EditText editTo;
    private EditText editUsername;
    private EditText editAdID;
    private Button buttonSend;
    private Button buttonSendLeft;
    private ImageButton buttonProfile;
    private ImageButton buttonDelete;
    Context context = this;
    String username;
    String adID;


    private int mInterval =60000;
    private Handler mHandler;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        myDb = new DatabaseHelper(this);
        mHandler = new Handler();

        userDb = new UserHelper(this);

        Cursor res = userDb.getUserAdId();
        if(res.getCount() == 0) {
            // show message
            username = "";
            adID = "";
        }
        while (res.moveToNext()) {
            username = res.getString(1);
            adID = res.getString(2);
        }


        setContentView(R.layout.activity_main);

        buttonSend = (Button) findViewById(R.id.send);
        buttonSendLeft = (Button) findViewById(R.id.send_left);
        buttonProfile = (ImageButton) findViewById(R.id.profile);
        buttonDelete = (ImageButton) findViewById(R.id.delete);

        listView = (ListView) findViewById(R.id.msgview);

        chatArrayAdapter = new ChatArrayAdapter(getApplicationContext(), R.layout.activity_right);
        listView.setAdapter(chatArrayAdapter);

        editTo = (EditText) findViewById(R.id.to);
        chatText = (EditText) findViewById(R.id.msg);

        /*chatText.setOnKeyListener(new View.OnKeyListener() {
            public boolean onKey(View v, int keyCode, KeyEvent event) {
                if ((event.getAction() == KeyEvent.ACTION_DOWN) && (keyCode == KeyEvent.KEYCODE_ENTER)) {
                    return sendChatMessage(true);
                }
                return false;
            }
        });*/


        listView.setTranscriptMode(AbsListView.TRANSCRIPT_MODE_ALWAYS_SCROLL);
        listView.setAdapter(chatArrayAdapter);

        //to scroll the list view to bottom on data change
        chatArrayAdapter.registerDataSetObserver(new DataSetObserver() {
            @Override
            public void onChanged() {
                super.onChanged();
                listView.setSelection(chatArrayAdapter.getCount() - 1);
            }
        });


        AddData();
        viewAll();
        PopulateAll();
        ProfileButton();
        DeleteButton();
        startRepeatingTask();

    }

    public  void DeleteButton() {

        buttonDelete.setOnClickListener(
                new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        myDb.deleteAll();
                        chatArrayAdapter.clear();
                    }
                }
        );
    }

    public  void ProfileButton() {

        buttonProfile.setOnClickListener(
                new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        showUserProfile();
                    }
                }
        );
    }

    public void PopulateAll(){
        Cursor res = myDb.getAllData();
        if(res.getCount() == 0) {
            return;
        }
        while (res.moveToNext()) {
            if(res.getString(1).contains(adID)) {
                sendChatMessage(res.getString(1), res.getString(2), res.getString(3), true);
            }
            else{
                sendChatMessage(res.getString(1), res.getString(2), res.getString(3), false);
            }
        }
    }

    public  void AddData() {

        buttonSend.setOnClickListener(
                new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        boolean isInserted = myDb.insertData(adID,
                                editTo.getText().toString(),
                                chatText.getText().toString(), 0);
                        sendChatMessage(true);
                        if(isInserted == true)
                            Toast.makeText(MainActivity.this,"Data Inserted",Toast.LENGTH_LONG).show();
                        else
                            Toast.makeText(MainActivity.this,"Data not Inserted",Toast.LENGTH_LONG).show();
                    }
                }
        );
    }

    public void viewAll() {
        buttonSendLeft.setOnClickListener(
                new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        Cursor res = myDb.getAllData();
                        if(res.getCount() == 0) {
                            // show message
                            showMessage("Error","Nothing found");
                            return;
                        }

                        StringBuffer buffer = new StringBuffer();
                        while (res.moveToNext()) {
                            buffer.append("Id :"+ res.getString(0)+"\n");
                            buffer.append("Message from :"+ res.getString(1)+"\n");
                            buffer.append("Message to :"+ res.getString(2)+"\n");
                            buffer.append("Message :"+ res.getString(3)+"\n");
                            buffer.append("Read :"+ res.getString(4)+"\n");
                            buffer.append("Sent :"+ res.getString(5)+"\n\n");
                        }

                        // Show all data
                        showMessage("Data",buffer.toString());
                    }
                }
        );
    }

    public void showMessage(String title,String Message){
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setCancelable(true);
        builder.setTitle(title);
        builder.setMessage(Message);
        builder.show();
    }

    public void showUserProfile(){
        AlertDialog.Builder alert = new AlertDialog.Builder(this);

        alert.setTitle("Account Settings");

        LayoutInflater factory = LayoutInflater.from(this);
        final View view = factory.inflate(R.layout.profile, null);
        alert.setView(view);

        editUsername = (EditText) view.findViewById(R.id.usernameinput);
        editAdID = (EditText) view.findViewById(R.id.adidinput);

        if(username != null) {
            editUsername.setText(username);
        }
        if(adID != null) {
            editAdID.setText(adID);
        }

        alert.setPositiveButton("Ok", new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int whichButton) {
                username = editUsername.getText().toString();
                adID = editAdID.getText().toString();
                registerWithAWS(username, adID,"null");
                userDb.deleteAll();
                userDb.insertData(username, adID);
                // Do something with value!
            }
        });

        alert.setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int whichButton) {
                // Canceled.

            }
        });

        alert.show();
    }

    private void registerWithAWS(String username, String adid, String publickey){
        OkHttpClient client = new OkHttpClient();

        MediaType mediaType = MediaType.parse("application/json");
        RequestBody body = RequestBody.create(mediaType, "{\n\t\"endpointId\":\""+ adid +"\",\n\t\"alias\": \""+ username +"\",\n\t\"publicKey\": \""+ publickey +"\"\n}");
        Request request = new Request.Builder()
                .url("https://162d26fmj1.execute-api.us-west-2.amazonaws.com/prod/endpoint/register")
                .post(body)
                .addHeader("Content-Type", "application/json")
                .addHeader("Accept", "*/*")
                .addHeader("Host", "162d26fmj1.execute-api.us-west-2.amazonaws.com")
                .addHeader("Accept-Encoding", "gzip, deflate")
                .addHeader("Content-Length", "71")
                .addHeader("Connection", "keep-alive")
                .addHeader("cache-control", "no-cache")
                .build();
        try {
            final String TAG = "MyActivity";
            Log.v(TAG, "THIS IS A TEST");
            client.newCall(request).enqueue(new Callback() {
                @Override
                public void onFailure(Call call, IOException e) {
                    call.cancel();
                }

                @Override
                public void onResponse(Call call, Response response) throws IOException {

                    final String myResponse = response.body().string();
                    Log.v(TAG, myResponse);

                }
            });


        }
        catch(Exception e) {
            String TAG = "MyActivity";
            Log.v(TAG, "BROKE");
            e.printStackTrace();
        }
    }

    private boolean sendChatMessage(boolean left) {
        String text = chatText.getText().toString();
        String from = adID;
        String to = editTo.getText().toString();
        chatArrayAdapter.add(new ChatMessage(left, text, from, to));

        editTo.setText("");
        chatText.setText("");
        return true;
    }

    private boolean sendChatMessage(String messageFrom, String messageTo, String message, boolean left) {
        String text = message;
        String from = messageFrom;
        String to = messageTo;
        chatArrayAdapter.add(new ChatMessage(left, text, from, to));
        return true;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        stopRepeatingTask();
    }

    private void notificationDialog(String messageFrom, String message) {
        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        String NOTIFICATION_CHANNEL_ID = "messaging";
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            @SuppressLint("WrongConstant") NotificationChannel notificationChannel = new NotificationChannel(NOTIFICATION_CHANNEL_ID, "My Notifications", NotificationManager.IMPORTANCE_MAX);
            // Configure the notification channel.
            notificationChannel.setDescription("Sample Channel description");
            notificationChannel.enableLights(true);
            notificationChannel.setLightColor(Color.RED);
            notificationChannel.setVibrationPattern(new long[]{0, 1000, 500, 1000});
            notificationChannel.enableVibration(true);
            notificationManager.createNotificationChannel(notificationChannel);
        }
        NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID);
        notificationBuilder.setAutoCancel(true)
                .setDefaults(Notification.DEFAULT_ALL)
                .setWhen(System.currentTimeMillis())
                .setSmallIcon(R.mipmap.ic_launcher)
                .setTicker("Messaging")
                //.setPriority(Notification.PRIORITY_MAX)
                .setContentTitle("New Message From " + messageFrom)
                .setContentText(message)
                .setContentInfo("Ad Messaging");
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent contentIntent = PendingIntent.getActivity(this, 0,
                notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT);
        notificationBuilder.setContentIntent(contentIntent);
        notificationManager.notify(1, notificationBuilder.build());
    }

    Runnable mStatusChecker = new Runnable() {
        private static final String TAG = "Recurring";
        @Override
        public void run() {
            try {
                myDb.UpdateData();
                Cursor data = myDb.getUnread();

                StringBuffer buffer = new StringBuffer();
                while (data.moveToNext()) {
                    notificationDialog(data.getString(1), data.getString(3));
                    if (data.getString(1).contains(adID)) {
                        sendChatMessage(data.getString(1), data.getString(2), data.getString(3), true);
                    } else {
                        sendChatMessage(data.getString(1), data.getString(2), data.getString(3), false);
                    }
                    myDb.updateRead(data.getString(0));
                }
                 //this function can change value of mInterval.
                //Toast toast = Toast.makeText(getApplicationContext(),"testing", Toast.LENGTH_LONG);
                //toast.show();

            } finally {
                // 100% guarantee that this always happens, even if
                // your update method throws an exception
                mHandler.postDelayed(mStatusChecker, mInterval);
            }
        }
    };

    void startRepeatingTask() {
        mStatusChecker.run();
    }

    void stopRepeatingTask() {
        mHandler.removeCallbacks(mStatusChecker);
    }
}