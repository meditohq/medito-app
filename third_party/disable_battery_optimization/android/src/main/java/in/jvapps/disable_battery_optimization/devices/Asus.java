package in.jvapps.disable_battery_optimization.devices;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import androidx.annotation.DrawableRes;


import in.jvapps.disable_battery_optimization.R;
import in.jvapps.disable_battery_optimization.utils.ActionsUtils;
import in.jvapps.disable_battery_optimization.utils.Manufacturer;

// TODO TESTS
public class Asus extends DeviceAbstract {

    private static final String ASUS_PACAKGE_MOBILEMANAGER = "com.asus.mobilemanager";
    private static final String ASUS_ACTIVITY_MOBILEMANAGER_FUNCTION_ACTIVITY = "com.asus.mobilemanager.entry.FunctionActivity";
    private static final String ASUS_ACTIVITY_MOBILEMANAGER_FUNCTION_AUTOSTART_ACTIVITY = "com.asus.mobilemanager.autostart.AutoStartActivity";

    @Override
    public boolean isThatRom() {
        return  Build.BRAND.equalsIgnoreCase(getDeviceManufacturer().toString()) ||
                Build.MANUFACTURER.equalsIgnoreCase(getDeviceManufacturer().toString()) ||
                Build.FINGERPRINT.toLowerCase().contains(getDeviceManufacturer().toString());
    }

    @Override
    public Manufacturer getDeviceManufacturer() {
        return Manufacturer.ASUS;
    }

    @Override
    public boolean isActionPowerSavingAvailable(Context context) {
        return super.isActionDozeModeNotNecessary(context);
    }

    @Override
    public boolean isActionAutoStartAvailable(Context context) {
        return true;
    }

    @Override
    public boolean isActionNotificationAvailable(Context context) {
        return true;
    }

    @Override
    public Intent getActionPowerSaving(Context context) {
        // Juste need to use the regular battery non optimization
        // permission =)
        return super.getActionDozeMode(context);
    }

    @Override
    public Intent getActionAutoStart(Context context) {
        Intent intent = ActionsUtils.createIntent();
        intent.putExtra("showNotice",true);
        intent.setComponent(new ComponentName(ASUS_PACAKGE_MOBILEMANAGER, ASUS_ACTIVITY_MOBILEMANAGER_FUNCTION_AUTOSTART_ACTIVITY));
        return intent;
    }

    @Override
    public Intent getActionNotification(Context context) {
        // Need to clic on notifications items
        Intent intent = ActionsUtils.createIntent();
        intent.putExtra("showNotice",true);
        intent.setComponent(new ComponentName(ASUS_PACAKGE_MOBILEMANAGER, ASUS_ACTIVITY_MOBILEMANAGER_FUNCTION_ACTIVITY));
        return intent;
    }

    @Override
    public String getExtraDebugInformations(Context context) {
        return null;
    }

    @Override
    @DrawableRes
    public int getHelpImageAutoStart(){
        return R.drawable.asus_autostart;
    }

    @Override
    @DrawableRes
    public int getHelpImageNotification(){
        return R.drawable.asus_notification;
    }
}
