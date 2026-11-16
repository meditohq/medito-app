package in.jvapps.disable_battery_optimization.devices;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;

import in.jvapps.disable_battery_optimization.utils.ActionsUtils;
import in.jvapps.disable_battery_optimization.utils.Manufacturer;

public class Meizu extends DeviceAbstract {

    private static final String MEIZU_DEFAULT_ACTION_APPSPEC = "com.meizu.safe.security.SHOW_APPSEC";
    private static final String MEIZU_POWERSAVING_ACTION = "com.meizu.power.PowerAppKilledNotification";
    private static final String MEIZU_DEFAULT_EXTRA_PACKAGE = "packageName";
    private static final String MEIZU_DEFAULT_PACKAGE = "com.meizu.safe";
    private static final String MEIZU_POWERSAVING_ACTIVITY_V2_2 = "com.meizu.safe.cleaner.RubbishCleanMainActivity";
    private static final String MEIZU_POWERSAVING_ACTIVITY_V3_4 = "com.meizu.safe.powerui.AppPowerManagerActivity";
    private static final String MEIZU_POWERSAVING_ACTIVITY_V3_7 = "com.meizu.safe.powerui.PowerAppPermissionActivity"; // == ACTION com.meizu.power.PowerAppKilledNotification
    private static final String MEIZU_NOTIFICATION_ACTIVITY = "com.meizu.safe.permission.NotificationActivity";

    @Override
    public boolean isThatRom() {
        return Build.BRAND.equalsIgnoreCase(getDeviceManufacturer().toString()) ||
                Build.MANUFACTURER.equalsIgnoreCase(getDeviceManufacturer().toString()) ||
                Build.FINGERPRINT.toLowerCase().contains(getDeviceManufacturer().toString());
    }

    @Override
    public Manufacturer getDeviceManufacturer() {
        return Manufacturer.MEIZU;
    }

    @Override
    public boolean isActionPowerSavingAvailable(Context context) {
        return true;
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
        Intent intent = ActionsUtils.createIntent();
        MEIZU_SECURITY_CENTER_VERSION mSecVersion = getMeizuSecVersion(context);
        intent.setAction(MEIZU_POWERSAVING_ACTION);
        if (ActionsUtils.isIntentAvailable(context, intent)) {
            return intent;
        }
        intent = ActionsUtils.createIntent();
        if (mSecVersion == MEIZU_SECURITY_CENTER_VERSION.SEC_2_2) {
            intent.setClassName(MEIZU_DEFAULT_PACKAGE, MEIZU_POWERSAVING_ACTIVITY_V2_2);
        } else if (mSecVersion == MEIZU_SECURITY_CENTER_VERSION.SEC_3_4) {
            intent.setClassName(MEIZU_DEFAULT_PACKAGE, MEIZU_POWERSAVING_ACTIVITY_V3_4);
        } else if (mSecVersion == MEIZU_SECURITY_CENTER_VERSION.SEC_3_7) {
            intent.setClassName(MEIZU_DEFAULT_PACKAGE, MEIZU_POWERSAVING_ACTIVITY_V3_7);
        } else {
            return getDefaultSettingAction(context);
        }
        return intent;
    }

    @Override
    public Intent getActionAutoStart(Context context) {
        return getDefaultSettingAction(context);
    }

    private Intent getDefaultSettingAction(Context context) {
        Intent intent = ActionsUtils.createIntent();
        intent.setAction(MEIZU_DEFAULT_ACTION_APPSPEC);
        intent.putExtra(MEIZU_DEFAULT_EXTRA_PACKAGE, context.getPackageName());
        return intent;
    }
    @Override
    public Intent getActionNotification(Context context) {
        MEIZU_SECURITY_CENTER_VERSION mSecVersion = getMeizuSecVersion(context);
        Intent intent = ActionsUtils.createIntent();
        if (mSecVersion == MEIZU_SECURITY_CENTER_VERSION.SEC_3_7 || mSecVersion == MEIZU_SECURITY_CENTER_VERSION.SEC_4_1) {
            intent.setComponent(new ComponentName(MEIZU_DEFAULT_PACKAGE, MEIZU_NOTIFICATION_ACTIVITY));
            return intent;
        } else {
            return getDefaultSettingAction(context);
        }
    }

    @Override
    public String getExtraDebugInformations(Context context) {
        StringBuilder stringBuilder = new StringBuilder();
        stringBuilder.append("MeizuSecVersionMethod:").append(getMeizuSecVersion(context));

        PackageManager manager = context.getPackageManager();
        PackageInfo info;
        String versionStr ="";
        try {
            info = manager.getPackageInfo(MEIZU_DEFAULT_PACKAGE, 0);
            versionStr= info.versionName;
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
        }
        stringBuilder.append("MeizuSecPackageVersion:").append(versionStr);

        // ----- PACAKGE INFORMATIONS -----
        stringBuilder.append(MEIZU_DEFAULT_ACTION_APPSPEC).append(ActionsUtils.isIntentAvailable(context, MEIZU_DEFAULT_ACTION_APPSPEC));
        stringBuilder.append(MEIZU_POWERSAVING_ACTION).append(ActionsUtils.isIntentAvailable(context, MEIZU_POWERSAVING_ACTION));
        stringBuilder.append(MEIZU_DEFAULT_PACKAGE+MEIZU_POWERSAVING_ACTIVITY_V2_2).append(ActionsUtils.isIntentAvailable(context, new ComponentName(MEIZU_DEFAULT_PACKAGE,MEIZU_POWERSAVING_ACTIVITY_V2_2)));
        stringBuilder.append(MEIZU_DEFAULT_PACKAGE+MEIZU_POWERSAVING_ACTIVITY_V3_4).append(ActionsUtils.isIntentAvailable(context, new ComponentName(MEIZU_DEFAULT_PACKAGE,MEIZU_POWERSAVING_ACTIVITY_V3_4)));
        stringBuilder.append(MEIZU_DEFAULT_PACKAGE+MEIZU_POWERSAVING_ACTIVITY_V3_7).append(ActionsUtils.isIntentAvailable(context, new ComponentName(MEIZU_DEFAULT_PACKAGE,MEIZU_POWERSAVING_ACTIVITY_V3_7)));
        stringBuilder.append(MEIZU_DEFAULT_PACKAGE+MEIZU_NOTIFICATION_ACTIVITY).append(ActionsUtils.isIntentAvailable(context, MEIZU_POWERSAVING_ACTION));
        return stringBuilder.toString();
    }

    @Override
    public int getHelpImagePowerSaving() {
        return 0;
    }

    private enum MEIZU_SECURITY_CENTER_VERSION {
        SEC_2_2, //Meizu security center : 2.2.0922, 2.2.0310;
        SEC_3_4, //Meizu security center : 3.4.0316;
        SEC_3_6, //Meizu security center : 3.6.0802;
        SEC_3_7, //Meizu security center : 3.7.1101;
        SEC_4_1, //Meizu security center : 4.1.10;
    }

    private MEIZU_SECURITY_CENTER_VERSION getMeizuSecVersion(Context context) {
        MEIZU_SECURITY_CENTER_VERSION v;
        try {
            PackageManager manager = context.getPackageManager();
            PackageInfo info = manager.getPackageInfo(MEIZU_DEFAULT_PACKAGE, 0);
            String versionStr = info.versionName; //2.2.0922;
            Log.i("Meizu security center :", versionStr);
            if (versionStr.startsWith("2")) {
                v = MEIZU_SECURITY_CENTER_VERSION.SEC_2_2;
            } else if (versionStr.startsWith("3")) {
                int d = Integer.parseInt(versionStr.substring(2, 3));
                Log.i("Meizu security center :", "d: " + d);
                if (d <= 4) {
                    v = MEIZU_SECURITY_CENTER_VERSION.SEC_3_4;
                } else if (d < 7) {
                    v = MEIZU_SECURITY_CENTER_VERSION.SEC_3_6;
                } else {
                    v = MEIZU_SECURITY_CENTER_VERSION.SEC_3_7;
                }
            } else if (versionStr.startsWith("4")) {
                v = MEIZU_SECURITY_CENTER_VERSION.SEC_4_1;
            } else {
                v = MEIZU_SECURITY_CENTER_VERSION.SEC_4_1;
            }
        } catch (Exception e) {
            v = MEIZU_SECURITY_CENTER_VERSION.SEC_4_1;
        }
        return v;
    }
}
