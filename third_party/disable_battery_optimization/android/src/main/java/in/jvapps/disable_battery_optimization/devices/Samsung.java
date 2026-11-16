package in.jvapps.disable_battery_optimization.devices;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import in.jvapps.disable_battery_optimization.R;
import in.jvapps.disable_battery_optimization.utils.ActionsUtils;
import in.jvapps.disable_battery_optimization.utils.Manufacturer;

public class Samsung extends DeviceAbstract {
    // crash "com.samsung.android.lool","com.samsung.android.sm.ui.battery.AppSleepListActivity"
    private static final String SAMSUNG_SYSTEMMANAGER_POWERSAVING_ACTION = "com.samsung.android.sm.ACTION_BATTERY";
    private static final String SAMSUNG_SYSTEMMANAGER_NOTIFICATION_ACTION = "com.samsung.android.sm.ACTION_SM_NOTIFICATION_SETTING";
    // ANDROID 7.0/8.0
    private static final String SAMSUNG_SYSTEMMANAGER_POWERSAVING_PACKAGE_V3 = "com.samsung.android.lool";
    private static final String SAMSUNG_SYSTEMMANAGER_POWERSAVING_PACKAGE_V3_ACTIVITY = "com.samsung.android.sm.ui.battery.BatteryActivity";

    // ANDROID 6.0
    private static final String SAMSUNG_SYSTEMMANAGER_POWERSAVING_PACKAGE_V2 = "com.samsung.android.sm_cn";
    private static final String SAMSUNG_SYSTEMMANAGER_POWERSAVING_PACKAGE_V2_ACTIVITY = "com.samsung.android.sm.ui.battery.BatteryActivity";

    // ANDROID 5.0/5.1
    private static final String SAMSUNG_SYSTEMMANAGER_POWERSAVING_PACKAGE_V1 = "com.samsung.android.sm";
    private static final String SAMSUNG_SYSTEMMANAGER_POWERSAVING_PACKAGE_V1_ACTIVITY = "com.samsung.android.sm.ui.battery.BatteryActivity";

    private static final String SAMSUNG_SYSTEMMANAGER_AUTOSTART_PACKAGE_V1 = "com.samsung.memorymanager";
    private static final String SAMSUNG_SYSTEMMANAGER_AUTOSTART_PACKAGE_V1_ACTIVITY = "com.samsung.memorymanager.RamActivity";

    @Override
    public boolean isThatRom() {
        return Build.BRAND.equalsIgnoreCase(getDeviceManufacturer().toString()) ||
                Build.MANUFACTURER.equalsIgnoreCase(getDeviceManufacturer().toString()) ||
                Build.FINGERPRINT.toLowerCase().contains(getDeviceManufacturer().toString());
    }

    @Override
    public Manufacturer getDeviceManufacturer() {
        return Manufacturer.SAMSUNG;
    }

    @Override
    public boolean isActionPowerSavingAvailable(Context context) {
        // SmartManager is not available before lollipop version
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP;
    }

    @Override
    public boolean isActionAutoStartAvailable(Context context) {
        return false;
    }

    @Override
    public boolean isActionNotificationAvailable(Context context) {
        return false;
    }

    @Override
    public boolean needToUseAlongwithActionDoseMode() {
        return true;
    }

    @Override
    public Intent getActionPowerSaving(Context context) {
        Intent intent = ActionsUtils.createIntent();
        intent.setAction(SAMSUNG_SYSTEMMANAGER_POWERSAVING_ACTION);
        if (ActionsUtils.isIntentAvailable(context, intent)) {
            return intent;
        }
        // reset
        intent = ActionsUtils.createIntent();
        intent.setComponent(new ComponentName(SAMSUNG_SYSTEMMANAGER_POWERSAVING_PACKAGE_V3,
                                              SAMSUNG_SYSTEMMANAGER_POWERSAVING_PACKAGE_V3_ACTIVITY));
        if (ActionsUtils.isIntentAvailable(context, intent)) {
            return intent;
        }

        intent.setComponent(new ComponentName(SAMSUNG_SYSTEMMANAGER_POWERSAVING_PACKAGE_V2,
                                              SAMSUNG_SYSTEMMANAGER_POWERSAVING_PACKAGE_V2_ACTIVITY));
        if (ActionsUtils.isIntentAvailable(context, intent)) {
            return intent;
        }
        intent.setComponent(new ComponentName(SAMSUNG_SYSTEMMANAGER_POWERSAVING_PACKAGE_V1,
                                              SAMSUNG_SYSTEMMANAGER_POWERSAVING_PACKAGE_V1_ACTIVITY));
        if (ActionsUtils.isIntentAvailable(context, intent)) {
            return intent;
        }
        return null;
    }

    // FIXME Currently not working : not available, ITS NOT AUTOSTART ITS MEMORY MANAGER
    @Override
    public Intent getActionAutoStart(Context context) {
        Intent intent = ActionsUtils.createIntent();
        intent.setComponent(new ComponentName(SAMSUNG_SYSTEMMANAGER_AUTOSTART_PACKAGE_V1,
                                              SAMSUNG_SYSTEMMANAGER_AUTOSTART_PACKAGE_V1_ACTIVITY));
        return intent;
    }

    // FIXME : NOTWORKOING NEED PERMISSIONS SETTINGS OR SOMETHINGS ELSE
    @Override
    public Intent getActionNotification(Context context) {
        Intent intent = ActionsUtils.createIntent();
        intent.setAction(SAMSUNG_SYSTEMMANAGER_NOTIFICATION_ACTION);
        return null;
    }

    @Override
    public String getExtraDebugInformations(Context context) {
        return null;
    }

    @Override
    public int getHelpImagePowerSaving() {
        return R.drawable.samsung;
    }
}
