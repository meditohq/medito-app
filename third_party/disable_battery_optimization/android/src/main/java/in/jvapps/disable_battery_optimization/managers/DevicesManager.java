package in.jvapps.disable_battery_optimization.managers;

import in.jvapps.disable_battery_optimization.devices.Asus;
import in.jvapps.disable_battery_optimization.devices.DeviceAbstract;
import in.jvapps.disable_battery_optimization.devices.DeviceBase;
import in.jvapps.disable_battery_optimization.devices.HTC;
import in.jvapps.disable_battery_optimization.devices.Huawei;
import in.jvapps.disable_battery_optimization.devices.Letv;
import in.jvapps.disable_battery_optimization.devices.Meizu;
import in.jvapps.disable_battery_optimization.devices.OnePlus;
import in.jvapps.disable_battery_optimization.devices.Oppo;
import in.jvapps.disable_battery_optimization.devices.Samsung;
import in.jvapps.disable_battery_optimization.devices.Vivo;
import in.jvapps.disable_battery_optimization.devices.Xiaomi;
import in.jvapps.disable_battery_optimization.devices.ZTE;
import in.jvapps.disable_battery_optimization.utils.LogUtils;
import in.jvapps.disable_battery_optimization.utils.SystemUtils;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class DevicesManager {

    private static List<DeviceAbstract> deviceBaseList = new ArrayList<>(Arrays.asList(
            new Asus(),
            new Huawei(),
            new Letv(),
            new Meizu(),
            new OnePlus(),
            new Oppo(),
            new Vivo(),
            new HTC(),
            new Samsung(),
            new Xiaomi(),
            new ZTE()));

    public static DeviceBase getDevice(){
        List<DeviceBase> currentDeviceBase =new ArrayList<>();
        for (DeviceBase deviceBase : deviceBaseList) {
            if(deviceBase.isThatRom()){
                currentDeviceBase.add(deviceBase);
            }
        }
        if(currentDeviceBase.size()>1){
            StringBuilder logDevices= new StringBuilder();
            for (DeviceBase deviceBase : currentDeviceBase) {
                logDevices.append(deviceBase.getDeviceManufacturer());
            }
            LogUtils.e(DevicesManager.class.getName(),"MORE THAN ONE CORRESPONDING:"+logDevices+"|"+
                    SystemUtils.getDefaultDebugInformation());
        }

        if (currentDeviceBase.size()>0) {
            return currentDeviceBase.get(0);
        }else {
            return null;
        }
    }
}
