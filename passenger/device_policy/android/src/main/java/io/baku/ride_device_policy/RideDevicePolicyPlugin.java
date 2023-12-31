package io.baku.ride_device_policy;

import android.app.Activity;
import android.app.admin.DeviceAdminReceiver;
import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.PowerManager;
import android.provider.Settings;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.List;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

/**
 * RideDevicePolicyPlugin
 */
public class RideDevicePolicyPlugin extends DeviceAdminReceiver
    implements FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
  private static final int REQUEST_CODE_ENABLE_ADMIN = 0;

  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private Context context;
  private ComponentName componentName;
  private DevicePolicyManager devicePolicyManager;
  private ActivityPluginBinding activityBinding;

  private Result adminRequest;
  private PowerManager.WakeLock wakeLock;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "ride_device_policy");
    channel.setMethodCallHandler(this);

    context = flutterPluginBinding.getApplicationContext();

    componentName = new ComponentName(context, getClass());
    devicePolicyManager = (DevicePolicyManager) context.getSystemService(Context.DEVICE_POLICY_SERVICE);

    final PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
    wakeLock = powerManager.newWakeLock(PowerManager.FULL_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP, "RideDevicePolicyPlugin:wakeUp");
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activityBinding = binding;
    binding.addActivityResultListener(this);
  }

  @Override
  public void onDetachedFromActivity() {
    if (adminRequest != null) {
      adminRequest.error("failed", "Activity detached.", null);
      adminRequest = null;
    }

    activityBinding.removeActivityResultListener(this);
    activityBinding = null;
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public boolean onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
    switch (requestCode) {
      case REQUEST_CODE_ENABLE_ADMIN:
        switch (resultCode) {
          case Activity.RESULT_OK:
            adminRequest.success(true);
            break;
          case Activity.RESULT_CANCELED:
            adminRequest.success(false);
            break;
          default:
            adminRequest.error(Integer.toString(resultCode), "Exceptional result from admin request.", data.toString());
            break;
        }
        adminRequest = null;
        return true;
      default:
        return false;
    }
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "requestAdminIfNeeded": {
        if (devicePolicyManager.isAdminActive(componentName)) {
          result.success(true);
          return;
        }

        if (activityBinding == null) {
          result.error("failed", "Result callback requires an activity.", null);
          return;
        }

        if (adminRequest != null) {
          throw new IllegalStateException("Unexpected uncompleted admin request.");
        }
        adminRequest = result;

        final Intent intent = new Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN);
        intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName);
        final String arguments = call.arguments();
        if (arguments != null) {
          intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, arguments);
        }
        activityBinding.getActivity().startActivityForResult(intent, REQUEST_CODE_ENABLE_ADMIN);
        // Result will be completed in callback.
        break;
      }
      case "setSystemSetting": {
        final List<String> arguments = call.arguments();
        if (Settings.System.putString(context.getContentResolver(), arguments.get(0), arguments.get(1))) {
          result.success(null);
        } else {
          result.error("failed", "android.provider.Settings.System.putString failed", null);
        }
        break;
      }
      case "getSystemSetting": {
        result.success(Settings.System.getString(context.getContentResolver(), call.arguments()));
        break;
      }
      case "home": {
        final Intent home = new Intent(Intent.ACTION_MAIN);
        home.addCategory(Intent.CATEGORY_HOME);
        home.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(home);
        result.success(null);
        break;
      }
      case "wakeUp": {
        // Other methods that didn't work:
        // * LayoutParams: ignored
        // * PowerManager: hidden API, not accessible through reflection
        // * Activity methods: insufficient API level.
        // Let the OS release the wake lock immediately.
        wakeLock.acquire(0);
        result.success(null);
        break;
      }
      case "lockNow": {
        devicePolicyManager.lockNow();
        result.success(null);
        break;
      }
      default:
        result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }
}
