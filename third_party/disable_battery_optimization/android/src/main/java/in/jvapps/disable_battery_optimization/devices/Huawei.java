package in.jvapps.disable_battery_optimization.devices;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;

import in.jvapps.disable_battery_optimization.R;
import in.jvapps.disable_battery_optimization.utils.ActionsUtils;
import in.jvapps.disable_battery_optimization.utils.Manufacturer;
import in.jvapps.disable_battery_optimization.utils.SystemUtils;

import java.util.ArrayList;
import java.util.List;

import static in.jvapps.disable_battery_optimization.utils.SystemUtils.getEmuiRomName;

public class Huawei extends DeviceAbstract {

    // TODO NOT SUR IT WORKS ON EMUI 5
    private static final String HUAWEI_ACTION_POWERSAVING = "huawei.intent.action.HSM_PROTECTED_APPS";
    private static final String HUAWEI_ACTION_AUTOSTART = "huawei.intent.action.HSM_BOOTAPP_MANAGER";
    private static final String HUAWEI_ACTION_NOTIFICATION = "huawei.intent.action.NOTIFICATIONMANAGER";
    private static final String HUAWEI_SYSTEMMANAGER_PACKAGE_NAME = "com.huawei.systemmanager";
    private static final String HUAWEI_SYSTEMMANAGER_AUTO_START_V1 = "com.huawei.systemmanager.optimize.bootstart.BootStartActivity";
    private static final String HUAWEI_SYSTEMMANAGER_AUTO_START_V2 = "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity";
    private static final String HUAWEI_SYSTEMMANAGER_AUTO_START_V3 = "com.huawei.permissionmanager.ui.MainActivity";
    private static final String HUAWEI_SYSTEMMANAGER_AUTO_START_V4 = "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity";

    //com.huawei.systemmanager/com.huawei.notificationmanager.ui.NotificationManagmentActivity // huawei.intent.action.NOTIFICATIONMANAGER
    @Override
    public boolean isThatRom() {
        return isEmotionUI_23() ||
                isEmotionUI_3() ||
                isEmotionUI_301() ||
                isEmotionUI_31() ||
                isEmotionUI_41() ||
                Build.BRAND.equalsIgnoreCase(getDeviceManufacturer().toString()) ||
                Build.MANUFACTURER.equalsIgnoreCase(getDeviceManufacturer().toString()) ||
                Build.FINGERPRINT.toLowerCase().contains(getDeviceManufacturer().toString());
    }

    public static boolean isEmotionUI_301() {
        return "EmotionUI_3.0.1".equalsIgnoreCase(getEmuiRomName());
    }

    public static boolean isEmotionUI_31() {
        return "EmotionUI_3.1".equalsIgnoreCase(getEmuiRomName());
    }

    public static boolean isEmotionUI_41() {
        return "EmotionUI_4.1".equalsIgnoreCase(getEmuiRomName());
    }

    public static boolean isEmotionUI_3() {
        return "EmotionUI_3.0".equalsIgnoreCase(getEmuiRomName());
    }

    public static boolean isEmotionUI_23() {
        return "EmotionUI_2.3".equalsIgnoreCase(getEmuiRomName()) || Build.DISPLAY.toLowerCase().contains("emui2.3") || "EMUI 2.3".equalsIgnoreCase(getEmuiRomName());
    }

    @Override
    public Manufacturer getDeviceManufacturer() {
        return Manufacturer.HUAWEI;
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
        intent.setAction(HUAWEI_ACTION_POWERSAVING);
        return intent;
    }

    @Override
    public Intent getActionAutoStart(Context context) {
        Intent intent = ActionsUtils.createIntent();
        intent.setAction(HUAWEI_ACTION_AUTOSTART);
        if (ActionsUtils.isIntentAvailable(context, intent)) {
            return intent;
        } else {
            intent = ActionsUtils.createIntent();
            intent.setComponent(SystemUtils.getResolvableComponentName(context, getComponentNameAutoStart(context)));
            return intent;
        }
    }

    @Override
    public Intent getActionNotification(Context context) {
        Intent intent = ActionsUtils.createIntent();
        intent.setAction(HUAWEI_ACTION_NOTIFICATION);
        return intent;
    }

    @Override
    public String getExtraDebugInformations(Context context) {
        StringBuilder stringBuilder = new StringBuilder();
        stringBuilder.append("ROM_VERSION").append(getEmuiRomName());

        stringBuilder.append("HuaweiSystemManagerVersionMethod:").append(getHuaweiSystemManagerVersion(context));

        PackageManager manager = context.getPackageManager();
        PackageInfo info;
        String versionStr = "";
        try {
            info = manager.getPackageInfo(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME, 0);
            versionStr = info.versionName;
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
        }

        stringBuilder.append("HuaweiSystemManagerPackageVersion:").append(versionStr);

        // ----- PACAKGE INFORMATIONS -----
        stringBuilder.append(HUAWEI_ACTION_AUTOSTART).append(ActionsUtils.isIntentAvailable(context, HUAWEI_ACTION_AUTOSTART));
        stringBuilder.append(HUAWEI_ACTION_POWERSAVING).append(ActionsUtils.isIntentAvailable(context, HUAWEI_ACTION_POWERSAVING));
        stringBuilder.append(HUAWEI_ACTION_NOTIFICATION).append(ActionsUtils.isIntentAvailable(context, HUAWEI_ACTION_NOTIFICATION));
        stringBuilder.append(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME + HUAWEI_SYSTEMMANAGER_AUTO_START_V1).append(ActionsUtils.isIntentAvailable(context, new ComponentName(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME, HUAWEI_SYSTEMMANAGER_AUTO_START_V1)));
        stringBuilder.append(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME + HUAWEI_SYSTEMMANAGER_AUTO_START_V2).append(ActionsUtils.isIntentAvailable(context, new ComponentName(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME, HUAWEI_SYSTEMMANAGER_AUTO_START_V2)));
        stringBuilder.append(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME + HUAWEI_SYSTEMMANAGER_AUTO_START_V3).append(ActionsUtils.isIntentAvailable(context, new ComponentName(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME, HUAWEI_SYSTEMMANAGER_AUTO_START_V3)));
        stringBuilder.append(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME + HUAWEI_SYSTEMMANAGER_AUTO_START_V4).append(ActionsUtils.isIntentAvailable(context, new ComponentName(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME, HUAWEI_SYSTEMMANAGER_AUTO_START_V4)));
        return stringBuilder.toString();
    }

    @Override
    public int getHelpImagePowerSaving() {
        return R.drawable.huawei_powersaving;
    }

    @Override
    public int getHelpImageAutoStart() {
        return R.drawable.huawei_autostart;
    }

    @SuppressWarnings("unused")
    private List<ComponentName> getComponentNameAutoStart(Context context) {
        int mVersion = getHuaweiSystemManagerVersion(context);
        final List<ComponentName> names = new ArrayList<>();
        if (mVersion == 4 || mVersion == 5) {
            names.add(new ComponentName(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME, HUAWEI_SYSTEMMANAGER_AUTO_START_V2));
        } else if (mVersion == 6) {
            names.add(new ComponentName(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME, HUAWEI_SYSTEMMANAGER_AUTO_START_V3));
            names.add(new ComponentName(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME, HUAWEI_SYSTEMMANAGER_AUTO_START_V4));
        } else {
            names.add(new ComponentName(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME, HUAWEI_SYSTEMMANAGER_AUTO_START_V1));
        }
        return names;
    }

    private static int getHuaweiSystemManagerVersion(Context context) {
        int version = 0;
        int versionNum = 0;
        int thirdPartFirtDigit = 0;
        try {
            PackageManager manager = context.getPackageManager();
            PackageInfo info = manager.getPackageInfo(HUAWEI_SYSTEMMANAGER_PACKAGE_NAME, 0);
            Log.i(Huawei.class.getName(), "manager info = " + info.toString());
            String versionStr = info.versionName;
            String[] versionTmp = versionStr.split("\\.");
            if (versionTmp.length >= 2) {
                if (Integer.parseInt(versionTmp[0]) == 5) {
                    versionNum = 500;
                } else if (Integer.parseInt(versionTmp[0]) == 4) {
                    versionNum = Integer.parseInt(versionTmp[0] + versionTmp[1] + versionTmp[2]);
                } else {
                    versionNum = Integer.parseInt(versionTmp[0] + versionTmp[1]);
                }

            }
            if (versionTmp.length >= 3) {
                thirdPartFirtDigit = Integer.parseInt(versionTmp[2].substring(0, 1));
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        if (versionNum >= 330) {
            if (versionNum >= 500) {
                version = 6;
            } else if (versionNum >= 400) {
                version = 5;
            } else if (versionNum >= 331) {
                version = 4;
            } else {
                version = (thirdPartFirtDigit == 6 || thirdPartFirtDigit == 4 || thirdPartFirtDigit == 2) ? 3 : 2;
            }
        } else if (versionNum != 0) {
            version = 1;
        }
        return version;
    }
}
