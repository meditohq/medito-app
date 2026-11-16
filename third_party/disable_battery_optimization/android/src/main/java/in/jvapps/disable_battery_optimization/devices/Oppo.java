package in.jvapps.disable_battery_optimization.devices;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import in.jvapps.disable_battery_optimization.R;
import in.jvapps.disable_battery_optimization.utils.ActionsUtils;
import in.jvapps.disable_battery_optimization.utils.Manufacturer;

public class Oppo extends DeviceAbstract {
    // TODO multiple intent in a same actions need to be refractor!
    /*
     * java.lang.SecurityException: Permission Denial: starting Intent { cmp=com.coloros.safecenter/.startupapp.StartupAppListActivity } from ProcessRecord{7eba0ba 27527:crb.call.follow.mycrm/u0a229} (pid=27527, uid=10229) requires oppo.permission.OPPO_COMPONENT_SAFE*/
    //coloros3.0


    private static final String p12 = "com.coloros.oppoguardelf";
    private static final String p12c1 = "com.coloros.powermanager.fuelgaue.PowerConsumptionActivity";
    private static final String p12c2 = "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity";

    //OLD == ColorOS V2.1
    private static final String p13 = "com.color.oppoguardelf";
    private static final String p13c1 = "com.color.safecenter.permission.startup.StartupAppListActivity";
    private static final String p13c2 = "com.color.safecenter.startupapp.StartupAppListActivity";

    private static final ComponentName[] OPPO_AUTOSTART = {new ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            new ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
            new ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            new ComponentName("com.color.safecenter", "com.color.safecenter.permission.startup.StartupAppListActivity"),
            new ComponentName("com.color.safecenter", "com.color.safecenter.startupapp.StartupAppListActivity")};

    private static final ComponentName[] OPPO_POWER_SAVE = {new ComponentName("com.color.oppoguardelfr", "com.coloros.powermanager.fuelgaue.PowerConsumptionActivity"),
            new ComponentName("com.color.oppoguardelf", "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity")};

    @Override
    public boolean isThatRom() {
        return Build.BRAND.equalsIgnoreCase(getDeviceManufacturer().toString()) ||
                Build.MANUFACTURER.equalsIgnoreCase(getDeviceManufacturer().toString()) ||
                Build.FINGERPRINT.toLowerCase().contains(getDeviceManufacturer().toString());
    }

    @Override
    public Manufacturer getDeviceManufacturer() {
        return Manufacturer.OPPO;
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
        for (ComponentName component : OPPO_POWER_SAVE) {
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
        for (ComponentName component : OPPO_AUTOSTART) {
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
        return 0;
    }

    @Override
    public int getHelpImageAutoStart() {
        return 0;
    }

/*
    private ComponentName getComponentName(Context context){
        if(ActionsUtils.isPackageExist(context,p1)){

        }
        else if(ActionsUtils.isPackageExist(context,p12)){

        }
        else if(ActionsUtils.isPackageExist(context,p13)){

        }
        else if(ActionsUtils.isPackageExist(context,p2)){

        }
        return null;
    }*/
}
