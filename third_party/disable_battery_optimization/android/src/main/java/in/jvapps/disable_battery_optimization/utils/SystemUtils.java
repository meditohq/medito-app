package in.jvapps.disable_battery_optimization.utils;

import android.annotation.TargetApi;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Process;
import android.os.UserManager;

import androidx.annotation.RequiresApi;

import android.util.Log;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.List;

public class SystemUtils {

    public static String getDefaultDebugInformation() {
        return "Display_id:" + Build.DISPLAY +
                "MODEL:" + Build.MODEL +
                "MANUFACTURER:" + Build.MANUFACTURER +
                "PRODUCT:" + Build.PRODUCT;
    }

    public static String getEmuiRomName() {
        try {
            return SystemUtils.getSystemProperty("ro.build.version.emui");
        } catch (Exception e) {
            return "";
        }
    }

    public static String getApplicationName(Context context) {
        PackageManager packageManager = context.getPackageManager();
        ApplicationInfo applicationInfo = null;
        try {
            applicationInfo = packageManager.getApplicationInfo(context.getApplicationInfo().packageName, 0);
        } catch (final PackageManager.NameNotFoundException ignored) {
        }
        return (String) (applicationInfo != null ? packageManager.getApplicationLabel(applicationInfo) : "Unknown");
    }

    public static String getMiuiRomName() {
        try {
            return SystemUtils.getSystemProperty("ro.miui.ui.version.name");
        } catch (Exception e) {
            return "";
        }
    }

    private static String getSystemProperty(String propName) {
        String line;
        BufferedReader input = null;
        try {
            java.lang.Process p = Runtime.getRuntime().exec("getprop " + propName);
            input = new BufferedReader(new InputStreamReader(p.getInputStream()), 1024);
            line = input.readLine();
            input.close();
        } catch (IOException ex) {
            Log.e(SystemUtils.class.getName(), "Unable to read system property " + propName, ex);
            return null;
        } finally {
            if (input != null) {
                try {
                    input.close();
                } catch (IOException e) {
                    Log.e(SystemUtils.class.getName(), "Exception while closing InputStream", e);
                }
            }
        }
        return line;
    }

    // INFO http://imsardine.simplbug.com/note/android/adb/commands/am-start.html

    /**
     * Open an Activity by using Application Manager System (prevent from crash permission exception)
     *
     * @param context         current application Context
     * @param packageName     pacakge name of the target application (exemple: com.huawei.systemmanager)
     * @param activityPackage activity name of the target application (exemple: .optimize.process.ProtectActivity)
     */
    @RequiresApi(Build.VERSION_CODES.JELLY_BEAN_MR1)
    @TargetApi(Build.VERSION_CODES.JELLY_BEAN_MR1)
    public static void startActivityByAMSystem(Context context, String packageName, String activityPackage)
            throws IOException {
        String cmd = "am start -n " + packageName + "/" + activityPackage;
        UserManager um = (UserManager) context.getSystemService(Context.USER_SERVICE);
        assert um != null;
        cmd += " --user " + um.getSerialNumberForUser(Process.myUserHandle());
        Runtime.getRuntime().exec(cmd);
    }

    /**
     * Open an Action by using Application Manager System (prevent from crash permission exception)
     *
     * @param context      current application Context
     * @param intentAction action of the target application (exemple: com.huawei.systemmanager)
     */
    @RequiresApi(Build.VERSION_CODES.JELLY_BEAN_MR1)
    @TargetApi(Build.VERSION_CODES.JELLY_BEAN_MR1)
    public static void startActionByAMSystem(Context context, String intentAction)
            throws IOException {
        String cmd = "am start -a " + intentAction;
        UserManager um = (UserManager) context.getSystemService(Context.USER_SERVICE);
        assert um != null;
        cmd += " --user " + um.getSerialNumberForUser(Process.myUserHandle());
        Runtime.getRuntime().exec(cmd);
    }

    public static ComponentName getResolvableComponentName(final Context context, List<ComponentName> componentNameList) {
        for (ComponentName componentName : componentNameList) {
            final Intent intent = new Intent();
            intent.setComponent(componentName);
            if (context.getPackageManager().resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY) != null)
                return componentName;
        }
        return null;
    }

    public static Intent getAppInfoIntent(String packageName) {
        Intent intent = new Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.setData(Uri.parse("package:" + packageName));
        return intent;
    }

    public static void openAppSettings(Context context, String packageName) {
        Intent intent = new Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.setData(Uri.parse("package:" + packageName));
        context.startActivity(intent);
    }
}
