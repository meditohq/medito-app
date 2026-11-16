package in.jvapps.disable_battery_optimization.utils;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import androidx.annotation.NonNull;

import java.util.List;

public class ActionsUtils {

    public static Intent createIntent() {
        Intent intent = new Intent();
        intent.addCategory(Intent.CATEGORY_DEFAULT);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        return intent;
    }
    public static String getExtrasDebugInformations(Intent intent){
        StringBuilder stringBuilder = new StringBuilder();
        if(intent !=null){
            stringBuilder.append("intent actions").append(intent.getAction());
            stringBuilder.append("intent conponent");
            ComponentName componentName = intent.getComponent();
            if(componentName!=null){
                stringBuilder.append("ComponentName package:").append(componentName.getPackageName());
                stringBuilder.append("ComponentName class:").append(componentName.getClassName());
            }else {
                stringBuilder.append("ComponentName is null");
            }
        }else {
            stringBuilder.append("intent is null");
        }
        return stringBuilder.toString();
    }

    public static boolean isIntentAvailable(@NonNull Context ctx, @NonNull String actionIntent) {
        return isIntentAvailable(ctx, ActionsUtils.createIntent().setAction(actionIntent));
    }

    public static boolean isIntentAvailable(@NonNull Context ctx, @NonNull ComponentName componentName) {
        return isIntentAvailable(ctx, ActionsUtils.createIntent().setComponent(componentName));
    }

    public static boolean isIntentAvailable(@NonNull Context ctx, @NonNull Intent intent) {
        final PackageManager mgr = ctx.getPackageManager();
        List<ResolveInfo> list =
                mgr.queryIntentActivities(intent,
                        PackageManager.MATCH_DEFAULT_ONLY);
        return list.size() > 0;
    }
}
