package in.jvapps.disable_battery_optimization.utils;

import android.util.Log;

public class LogUtils {

    public static void i(String tag, String message){
        Log.i(tag,message);
        //HyperLog.i(tag,message);
    }
    public static void e(String tag, String message){
        Log.e(tag,message);
        //HyperLog.e(tag,message);
    }
}
