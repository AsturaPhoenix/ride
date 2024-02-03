package io.baku.ride_device_policy;

import android.app.Activity;
import android.app.admin.DeviceAdminReceiver;
import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.os.PowerManager;
import android.provider.Settings;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.List;
import java.util.regex.Pattern;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

/**
 * RideDevicePolicyPlugin
 */
public class RideDevicePolicyPlugin extends DeviceAdminReceiver
    implements FlutterPlugin, MethodCallHandler, StreamHandler, ActivityAware, PluginRegistry.ActivityResultListener {
  private static final int
      REQUEST_CODE_ENABLE_ADMIN = 0x00,
      REQUEST_CODE_ENABLE_ACCESSIBILITY = 0x01;

  private MethodChannel channel;
  private EventChannel windowEvents;
  private Context context;
  private ComponentName componentName;
  private DevicePolicyManager devicePolicyManager;
  private AudioManager audioManager;
  private ActivityPluginBinding activityBinding;

  private Result activityResult;
  private PowerManager.WakeLock wakeLock;
  private int maxVolume;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "ride_device_policy");
    channel.setMethodCallHandler(this);
    windowEvents = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "ride_device_policy.windowEvents");
    windowEvents.setStreamHandler(this);

    context = flutterPluginBinding.getApplicationContext();

    componentName = new ComponentName(context, getClass());
    devicePolicyManager = (DevicePolicyManager) context.getSystemService(Context.DEVICE_POLICY_SERVICE);
    audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);

    final PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
    wakeLock = powerManager.newWakeLock(PowerManager.FULL_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP, "RideDevicePolicyPlugin:wakeUp");

    maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activityBinding = binding;
    binding.addActivityResultListener(this);
  }

  @Override
  public void onDetachedFromActivity() {
    if (activityResult != null) {
      activityResult.error("failed", "Activity detached.", null);
      activityResult = null;
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
      case REQUEST_CODE_ENABLE_ACCESSIBILITY:
        switch (resultCode) {
          case Activity.RESULT_OK:
            activityResult.success(true);
            break;
          case Activity.RESULT_CANCELED:
            activityResult.success(false);
            break;
          default:
            activityResult.error(Integer.toString(resultCode), "Exceptional activity result.", data.toString());
            break;
        }
        activityResult = null;
        return true;
      default:
        return false;
    }
  }

  private boolean isAccessibilityActive() {
    final int accessibilityEnabled;
    try {
      accessibilityEnabled = Settings.Secure.getInt(context.getContentResolver(), android.provider.Settings.Secure.ACCESSIBILITY_ENABLED);
    } catch (Settings.SettingNotFoundException e) {
      return false;
    }

    if (accessibilityEnabled == 1) {
      final String service = context.getPackageName() + "/" + RideAccessibilityService.class.getCanonicalName();
      final String accessibilityServices = Settings.Secure.getString(context.getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
      return accessibilityServices != null && Pattern.matches("(?:^|:)" + service + "(?:$|:)", accessibilityServices);
    }
    return false;
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

        if (activityResult != null) {
          throw new IllegalStateException("Unexpected uncompleted activity result.");
        }
        activityResult = result;

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
      case "requestAccessibilityIfNeeded": {
        if (isAccessibilityActive()) {
          result.success(true);
          return;
        }

        if (activityBinding == null) {
          result.error("failed", "Result callback requires an activity.", null);
          return;
        }

        if (activityResult != null) {
          throw new IllegalStateException("Unexpected uncompleted activity result.");
        }
        // TODO: This actually won't get us what we want, since the UI is a toggle switch on the settings menu.
        // Instead, we probably want to do something when the service starts.
        activityResult = result;

        final Intent intent = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
        activityBinding.getActivity().startActivityForResult(intent, REQUEST_CODE_ENABLE_ACCESSIBILITY);
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
      case "setVolume": {
        final double volume = call.arguments();
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, (int)Math.ceil(volume * maxVolume), 0);
        result.success(null);
        break;
      }
      default:
        result.notImplemented();
    }
  }

  @Override
  public void onListen(Object arguments, EventSink events) {
    RideAccessibilityService.eventSink = events;
  }

  @Override
  public void onCancel(Object arguments) {
    RideAccessibilityService.eventSink = null;
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    windowEvents.setStreamHandler(null);
  }
}
