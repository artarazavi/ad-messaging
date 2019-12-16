package com.example.chatlayout;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.os.Environment;
import java.io.File;

public class DatabaseHelper extends SQLiteOpenHelper {
    public static final File  DATABASE_FILE_PATH = Environment.getExternalStorageDirectory();
    public static final String DATABASE_NAME = "Msgs.db";
    public static final String TABLE_NAME = "msgs_table";
    public static final String COL_1 = "ID";
    public static final String COL_2 = "NAMEFROM";
    public static final String COL_3 = "NAMETO";
    public static final String COL_4 = "MESSAGE";
    public static final String COL_5 = "READ";
    public static final String COL_6 = "SENT";


    public DatabaseHelper(Context context) {
        super(context, DATABASE_FILE_PATH + File.separator + DATABASE_NAME, null, 1);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("create table " + TABLE_NAME +" (ID INTEGER PRIMARY KEY AUTOINCREMENT,NAMEFROM TEXT,NAMETO TEXT,MESSAGE TEXT,READ INTEGER,SENT INTEGER)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        db.execSQL("DROP TABLE IF EXISTS "+TABLE_NAME);
        onCreate(db);
    }

    public boolean insertData(String namefrom,String nameto,String message, int sent) {
        SQLiteDatabase db = this.getWritableDatabase();
        ContentValues contentValues = new ContentValues();
        contentValues.put(COL_2,namefrom);
        contentValues.put(COL_3,nameto);
        contentValues.put(COL_4,message);
        contentValues.put(COL_5,1);
        contentValues.put(COL_6,sent);
        long result = db.insert(TABLE_NAME,null ,contentValues);
        if(result == -1)
            return false;
        else
            return true;
    }

    public Cursor getAllData() {
        SQLiteDatabase db = this.getWritableDatabase();
        Cursor res = db.rawQuery("select * from "+TABLE_NAME,null);
        return res;
    }

    public Cursor getUnread() {
        SQLiteDatabase db = this.getWritableDatabase();
        Cursor res = db.rawQuery("select * from "+TABLE_NAME+" where read = 0",null);
        return res;
    }

    public void UpdateData() {
        SQLiteDatabase db = this.getWritableDatabase();
    }

    public boolean updateData(String id,String namefrom,String nameto,String message) {
        SQLiteDatabase db = this.getWritableDatabase();
        ContentValues contentValues = new ContentValues();
        contentValues.put(COL_1,id);
        contentValues.put(COL_2,namefrom);
        contentValues.put(COL_3,nameto);
        contentValues.put(COL_4,message);
        db.update(TABLE_NAME, contentValues, "ID = ?",new String[] { id });
        return true;
    }

    public boolean updateRead(String id) {
        SQLiteDatabase db = this.getWritableDatabase();
        ContentValues contentValues = new ContentValues();
        contentValues.put(COL_1,id);
        contentValues.put(COL_5,1);
        db.update(TABLE_NAME, contentValues, "ID = ?",new String[] { id });
        return true;
    }

    public Integer deleteData (String id) {
        SQLiteDatabase db = this.getWritableDatabase();
        return db.delete(TABLE_NAME, "ID = ?",new String[] {id});
    }

    public Integer deleteAll () {
        SQLiteDatabase db = this.getWritableDatabase();
        return db.delete(TABLE_NAME, null,null);
    }
}