package in.jvapps.disable_battery_optimization.managers;

import android.content.Context;
import android.content.Intent;

import androidx.annotation.Nullable;

import in.jvapps.disable_battery_optimization.devices.DeviceBase;
import in.jvapps.disable_battery_optimization.utils.ActionsUtils;
import in.jvapps.disable_battery_optimization.utils.LogUtils;
import in.jvapps.disable_battery_optimization.utils.SystemUtils;

public class KillerManager {

    public enum Actions {
        ACTION_AUTOSTART("ACTION_AUTOSTART"),
        ACTION_NOTIFICATIONS("ACTION_NOTIFICATIONS"),
        ACTION_POWERSAVING("ACTION_POWERSAVING");

        private String mValue;

        Actions(String value) {
            this.mValue = value;
        }

        public String toString() {
            return this.mValue;
        }
    }

    private static DeviceBase sDevice;

    public static DeviceBase getDevice() {
        return sDevice;
    }

    public static void init(Context context) {
        // log error into a distant request bin logs for helps to debug
        // please do no change the adress
        /*HyperLog.initialize(context);
        HyperLog.setLogLevel(Log.VERBOSE);
        HyperLog.setURL("API URL");*/
        sDevice = DevicesManager.getDevice();
    }


    public static boolean isActionAvailable(Context context, Actions actions) {
        sDevice = DevicesManager.getDevice();
        boolean actionAvailable = false;
        if (sDevice != null) {
            switch (actions) {
                case ACTION_AUTOSTART:
                    actionAvailable = sDevice.isActionAutoStartAvailable(context);
                    break;
                case ACTION_POWERSAVING:
                    actionAvailable = sDevice.isActionPowerSavingAvailable(context);
                    break;
                case ACTION_NOTIFICATIONS:
                    actionAvailable = sDevice.isActionNotificationAvailable(context);
                    break;
            }
        }
        return actionAvailable;
    }

    /**
     * Return the intent for a specific action
     *
     * @param context the current context
     * @param actions the wanted actions
     * @return the intent
     */
    @Nullable
    private static Intent getIntentFromAction(Context context, Actions actions) {
        init(context);
        sDevice = DevicesManager.getDevice();
        if (sDevice != null) {
            Intent intent = null;
            switch (actions) {
                case ACTION_AUTOSTART:
                    intent = sDevice.getActionAutoStart(context);
                    break;
                case ACTION_POWERSAVING:
                    intent = sDevice.getActionPowerSaving(context);
                    break;
                case ACTION_NOTIFICATIONS:
                    intent = sDevice.getActionNotification(context);
                    break;
            }
            if (intent != null && ActionsUtils.isIntentAvailable(context, intent)) {
                // Intent found action succeed
                return intent;
            } else {
                LogUtils.e(KillerManager.class.getName(), "INTENT NOT FOUND :" +
                        ActionsUtils.getExtrasDebugInformations(intent) + "Actions \n" +
                        actions.name() + "SYSTEM UTILS \n" +
                        SystemUtils.getDefaultDebugInformation() + "DEVICE \n" +
                        sDevice.getExtraDebugInformations(context));
                // Intent not found action failed
                return null;
            }
        } else {
            // device not found action failed
            return null;
               /* LogUtils.e(KillerManager.class.getName(), "DEVICE NOT FOUND" + "SYSTEM UTILS \n" +
                        SystemUtils.getDefaultDebugInformation());*/
        }
    }

    /**
     * Execute the action
     *
     * @param context the current context
     * @param actions the wanted action to execute
     * @return true : action succeed; false action failed
     */
    public static boolean doAction(Context context, Actions actions) {
        // Avoid main app to crash when intent denied by using try catch
        try {
            Intent intent = getIntentFromAction(context, actions);
            if (intent != null && ActionsUtils.isIntentAvailable(context, intent)) {
                context.startActivity(intent);
                // Intent found action succeed
                return true;
            }

        } catch (Exception e) {
            // Exception handle action failed
            LogUtils.e(KillerManager.class.getName(), e.getMessage());
            return false;
        }
        return false;
    }

    public static void doActionAutoStart(Context context) {
        doAction(context, Actions.ACTION_AUTOSTART);
    }

    public static void doActionNotification(Context context) {
        doAction(context, Actions.ACTION_NOTIFICATIONS);
    }

    public static void doActionPowerSaving(Context context) {
        doAction(context, Actions.ACTION_POWERSAVING);
    }
}
