package io.baku.overlay_window;

import static android.view.WindowManager.LayoutParams.*;

import android.accessibilityservice.AccessibilityService;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;
import android.view.View;
import android.view.WindowManager;
import android.view.WindowManager.LayoutParams;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Future;

import io.flutter.FlutterInjector;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.android.FlutterSurfaceView;
import io.flutter.embedding.android.FlutterView;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter;
import io.flutter.embedding.engine.plugins.service.ServiceAware;
import io.flutter.embedding.engine.plugins.service.ServicePluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

/**
 * OverlayWindowPlugin
 */
public class OverlayWindowPlugin implements FlutterPlugin, MethodCallHandler, ServiceAware, ActivityAware, PluginRegistry.ActivityResultListener {
  private static final int
      REQUEST_CODE_ENABLE_OVERLAYS = 0x20;

  /**
   * Set this to elevate overlay windows to accessibility overlays, which are necessary to receive
   * touch events over some navigation bars.
   */
  public static Future<AccessibilityService> accessibilityService;

  private static class Window {
    final OverlayWindowPlugin bindings;
    final FlutterView view;
    final FlutterEngine engine;

    public Window(OverlayWindowPlugin bindings, FlutterView view, FlutterEngine engine) {
      this.bindings = bindings;
      this.view = view;
      this.engine = engine;
    }
  }

  private static void applyParams(LayoutParams params, List<Number> serializedParams) {
    if (serializedParams.get(0) != null) {
      params.flags = serializedParams.get(0).intValue();
    }
    if (serializedParams.get(1) != null) {
      params.gravity = serializedParams.get(1).intValue();
    }
    if (serializedParams.get(2) != null) {
      params.x = serializedParams.get(2).intValue();
    }
    if (serializedParams.get(3) != null) {
      params.y = serializedParams.get(3).intValue();
    }
    if (serializedParams.get(4) != null) {
      params.width = serializedParams.get(4).intValue();
    }
    if (serializedParams.get(5) != null) {
      params.height = serializedParams.get(5).intValue();
    }
  }

  private MethodChannel channel;
  private Context context;
  private ServicePluginBinding serviceBinding;
  private ActivityPluginBinding activityBinding;

  private WindowManager windowManager;

  private static int nextHandle;
  private static final Map<Integer, Window> windows = new HashMap<>();

  private Result activityResult;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "overlay_window");
    channel.setMethodCallHandler(this);

    context = flutterPluginBinding.getApplicationContext();

    windowManager = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
  }

  private List<Runnable> taskQueue;

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    synchronized (windows) {
      if (accessibilityService != null) {
        if (accessibilityService.isDone()) {
          try {
            windowManager = (WindowManager) accessibilityService.get().getSystemService(Context.WINDOW_SERVICE);
          } catch (Exception e) {
            Log.e("OverlayWindowPlugin", "Failed to elevate to accessibility service.", e);
            accessibilityService = null;
          }
        } else {
          if (taskQueue == null) {
            taskQueue = new ArrayList<>();
            new Thread(() -> {
              try {
                accessibilityService.get();
                synchronized (windows) {
                  if (taskQueue != null) {
                    for (final Runnable task : taskQueue) {
                      task.run();
                    }
                  }
                  taskQueue = null;
                }
              } catch (ExecutionException | InterruptedException _) {
              }
            }).start();
          }
          taskQueue.add(() -> onMethodCall(call, result));
          return;
        }
      }

      switch (call.method) {
        case "requestPermissions":
          if (Build.VERSION.SDK_INT >= 23) {
            if (activityBinding == null) {
              result.error("failed", "Result callback requires an activity.", null);
              return;
            }

            if (activityResult != null) {
              throw new IllegalStateException("Unexpected uncompleted activity result.");
            }
            activityResult = result;

            if (!Settings.canDrawOverlays(context)) {
              final Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                  Uri.parse("package:" + context.getPackageName()));
              activityBinding.getActivity().startActivityForResult(intent, REQUEST_CODE_ENABLE_OVERLAYS);
            }
          } else {
            result.success(true);
          }
          break;
        case "hasPermissions":
          result.success(Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(context));
          break;
        case "createWindow": {
          final List<Number> arguments = call.arguments();
          final long entrypoint = arguments.get(0).longValue();
          final LayoutParams params = new LayoutParams(
              accessibilityService != null && Build.VERSION.SDK_INT >= 22 ?
                  TYPE_ACCESSIBILITY_OVERLAY :
                  Build.VERSION.SDK_INT >= 26 ? TYPE_APPLICATION_OVERLAY : TYPE_SYSTEM_ALERT,
              FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCH_MODAL,
              PixelFormat.TRANSLUCENT
          );
          applyParams(params, arguments.subList(1, 7));

          final Window window = new Window(
              this,
              new FlutterView(context, new FlutterSurfaceView(context, true)),
              new FlutterEngine(context));

          final int handle = nextHandle++;
          windows.put(handle, window);

          window.engine.getDartExecutor().executeDartEntrypoint(
              new DartExecutor.DartEntrypoint(
                  FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                  "package:overlay_window/overlay_window_method_channel.dart",
                  "overlayMain"),
              Arrays.asList(Long.toString(entrypoint), Integer.toString(handle)));

          if (serviceBinding != null) {
            attachToService(window.engine);
          }
          if (activityBinding != null) {
            attachToActivity(window.engine);
          }

          window.view.attachToFlutterEngine(window.engine);
          windowManager.addView(window.view, params);
          window.engine.getLifecycleChannel().appIsResumed();

          result.success(handle);
          break;
        }
        case "updateWindow": {
          final List<Number> arguments = call.arguments();
          final int handle = arguments.get(0).intValue();
          final Window window = windows.get(handle);

          if (window == null) {
            result.error("Argument exception", "No window for handle " + handle, null);
            return;
          }

          final LayoutParams params = (LayoutParams) window.view.getLayoutParams();
          applyParams(params, arguments.subList(1, 7));
          windowManager.updateViewLayout(window.view, params);

          result.success(null);
          break;
        }
        case "setVisibility": {
          final List<Integer> arguments = call.arguments();
          final int handle = arguments.get(0);
          final Window window = windows.get(handle);
          final int visibility = arguments.get(1), oldVisibility = window.view.getVisibility();

          if (oldVisibility == View.VISIBLE && visibility != View.VISIBLE) {
            window.engine.getLifecycleChannel().appIsPaused();
          }
          window.view.setVisibility(arguments.get(1));
          if (oldVisibility != View.VISIBLE && visibility == View.VISIBLE) {
            window.engine.getLifecycleChannel().appIsResumed();
          }

          result.success(null);
          break;
        }
        case "destroyWindow": {
          final int handle = call.arguments();
          final Window window = windows.remove(handle);

          if (window == null) {
            result.error("Argument exception", "No window for handle " + handle, null);
            return;
          }

          windowManager.removeView(window.view);
          window.engine.getLifecycleChannel().appIsDetached();

          if (window.bindings.serviceBinding != null) {
            window.engine.getServiceControlSurface().detachFromService();
          }
          if (window.bindings.activityBinding != null) {
            window.engine.getActivityControlSurface().detachFromActivity();
          }

          window.engine.destroy();

          result.success(null);
          break;
        }
        default:
          result.notImplemented();
      }
    }
  }

  @Override
  public boolean onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
    switch (requestCode) {
      case REQUEST_CODE_ENABLE_OVERLAYS:
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

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    synchronized (windows) {
      taskQueue = null;
    }
    windowManager = null;
    channel.setMethodCallHandler(null);
  }

  private void attachToService(FlutterEngine engine) {
    engine.getServiceControlSurface().attachToService(
        serviceBinding.getService(),
        null,
        false); // TODO: This is not trivial to determine, and doesn't appear to be used.
  }

  private void attachToActivity(FlutterEngine engine) {
    engine.getActivityControlSurface().attachToActivity(
        ((FlutterActivity) activityBinding.getActivity()).getExclusiveAppComponent(),
        FlutterLifecycleAdapter.getActivityLifecycle(activityBinding));
  }

  @Override
  public void onAttachedToService(@NonNull ServicePluginBinding binding) {
    serviceBinding = binding;
    synchronized (windows) {
      for (final Window window : windows.values()) {
        if (window.bindings == this) {
          attachToService(window.engine);
        }
      }
    }
  }

  @Override
  public void onDetachedFromService() {
    synchronized (windows) {
      for (final Window window : windows.values()) {
        if (window.bindings == this) {
          window.engine.getServiceControlSurface().detachFromService();
        }
      }
    }
    serviceBinding = null;
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activityBinding = binding;
    synchronized (windows) {
      for (final Window window : windows.values()) {
        if (window.bindings == this) {
          attachToActivity(window.engine);
        }
      }
    }
    binding.addActivityResultListener(this);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    synchronized (windows) {
      for (final Window window : windows.values()) {
        if (window.bindings == this) {
          window.engine.getActivityControlSurface().detachFromActivityForConfigChanges();
        }
      }
    }
    activityBinding = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public void onDetachedFromActivity() {
    synchronized (windows) {
      for (final Window window : windows.values()) {
        if (window.bindings == this) {
          window.engine.getActivityControlSurface().detachFromActivity();
        }
      }
    }
    activityBinding = null;
  }
}
