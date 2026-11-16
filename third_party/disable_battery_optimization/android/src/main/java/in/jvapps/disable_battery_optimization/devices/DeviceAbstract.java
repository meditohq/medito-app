package in.jvapps.disable_battery_optimization.devices;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;
import androidx.annotation.DrawableRes;

import in.jvapps.disable_battery_optimization.utils.ActionsUtils;
import in.jvapps.disable_battery_optimization.utils.LogUtils;

public abstract class DeviceAbstract implements DeviceBase {

    @Override
    public boolean needToUseAlongwithActionDoseMode(){
        return false;
    }

    @Override
    @DrawableRes
    public int getHelpImageAutoStart(){
        return 0;
    }

    @Override
    @DrawableRes
    public int getHelpImageNotification(){
        return 0;
    }

    @DrawableRes
    @Override
    public int getHelpImagePowerSaving() {
        return 0;
    }

    @Override
    public boolean isActionDozeModeNotNecessary(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            assert pm != null;
            return pm.isIgnoringBatteryOptimizations(context.getPackageName());
        }
        return false;
    }

    @Override
    public Intent getActionDozeMode(Context context) {
        //Android 7.0+ Doze
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            assert pm != null;
            boolean ignoringBatteryOptimizations = pm.isIgnoringBatteryOptimizations(context.getPackageName());
            if (!ignoringBatteryOptimizations) {
                Intent dozeIntent = ActionsUtils.createIntent();
                // Cannot fire Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                // due to Google play device policy restriction !
                dozeIntent.setAction(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
                dozeIntent.setData(Uri.parse("package:" + context.getPackageName()));
                return dozeIntent;
            } else {
                LogUtils.i(this.getClass().getName(), "getActionDozeMode" + "App is already enable to ignore doze " +
                        "battery optimization");
            }
        }
        return null;
    }
}
