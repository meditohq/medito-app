package in.jvapps.disable_battery_optimization.devices;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import in.jvapps.disable_battery_optimization.R;
import in.jvapps.disable_battery_optimization.utils.ActionsUtils;
import in.jvapps.disable_battery_optimization.utils.Manufacturer;

public class Vivo extends DeviceAbstract {
// TODO multiple intent in a same actions !
    // Starting: Intent { cmp=com.vivo.permissionmanager/.activity.BgStartUpManagerActivity }
    //java.lang.SecurityException: Permission Denial: starting Intent { flg=0x10000000 cmp=com.vivo.permissionmanager/.activity.BgStartUpManagerActivity } from null (pid=28141, uid=2000) not exported from uid 1000

    private final String p1 = "com.iqoo.secure";
    private final String p1c1 = "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity";
    private final String p1c2 = "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager";

    private final String p2 = "com.vivo.permissionmanager";
    private final String p2c1 = "com.vivo.permissionmanager.activity.BgStartUpManagerActivity";

    private static final ComponentName[] VIVO_AUTOSTART = {new ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            new ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"),
            new ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")};

    private static final ComponentName[] VIVO_POWER_SAVE = {new ComponentName("com.vivo.abe", "com.vivo.applicationbehaviorengine.ui.ExcessivePowerManagerActivity")};

    // "com.vivo.abe", "com.vivo.applicationbehaviorengine.ui.ExcessivePowerManagerActivity"
    //com.iqoo.secure.MainGuideActivity ??
    @Override
    public boolean isThatRom() {
        return Build.BRAND.equalsIgnoreCase(getDeviceManufacturer().toString()) ||
                Build.MANUFACTURER.equalsIgnoreCase(getDeviceManufacturer().toString()) ||
                Build.FINGERPRINT.toLowerCase().contains(getDeviceManufacturer().toString());
    }

    @Override
    public Manufacturer getDeviceManufacturer() {
        return Manufacturer.VIVO;
    }

    @Override
    public boolean isActionPowerSavingAvailable(Context context) {
        return getActionPowerSaving(context) != null;
    }

    @Override
    public boolean isActionAutoStartAvailable(Context context) {
        return getActionAutoStart(context) != null;
    }

    @Override
    public boolean isActionNotificationAvailable(Context context) {
        return false;
    }

    @Override
    public Intent getActionPowerSaving(Context context) {
        Intent intent = null;
        for (ComponentName component : VIVO_POWER_SAVE) {
            if (ActionsUtils.isIntentAvailable(context, component)) {
                intent = ActionsUtils.createIntent();
                intent.setComponent(component);
                break;
            }
        }
        return intent;
    }

    @Override
    public Intent getActionAutoStart(Context context) {
        Intent intent = null;
        for (ComponentName component : VIVO_AUTOSTART) {
            if (ActionsUtils.isIntentAvailable(context, component)) {
                intent = ActionsUtils.createIntent();
                intent.setComponent(component);
                break;
            }
        }
        return intent;
    }

    @Override
    public Intent getActionNotification(Context context) {
        return null;
    }

    @Override
    public String getExtraDebugInformations(Context context) {
        return null;
    }

    @Override
    public int getHelpImagePowerSaving() {
        return R.drawable.vivo_power_save;
    }

    @Override
    public int getHelpImageAutoStart() {
        return R.drawable.vivo_auto_start;
    }
/*
    @Override
    public List<ComponentName> getAutoStartSettings(Context context) {
        List<ComponentName> componentNames = new ArrayList<>();
        if(ActionsUtils.isPackageExist(context, p1)){
            componentNames.add(new ComponentName(p1,p1c1));
            componentNames.add(new ComponentName(p1,p1c2));
        }
        if(ActionsUtils.isPackageExist(context,p2)){
            componentNames.add(new ComponentName(p2,p2c1));
        }
        return componentNames;
    }*/
}
