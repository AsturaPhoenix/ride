package io.baku.overlay_window;

import static android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
import static android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL;
import static android.view.WindowManager.LayoutParams.TYPE_SYSTEM_ALERT;

import android.content.Context;
import android.graphics.PixelFormat;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.WindowManager.LayoutParams;

import androidx.annotation.NonNull;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

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

/**
 * OverlayWindowPlugin
 */
public class OverlayWindowPlugin implements FlutterPlugin, MethodCallHandler, ServiceAware, ActivityAware {
  private static class Window {
    final FlutterView view;
    final FlutterEngine engine;

    public Window(FlutterView view, FlutterEngine engine) {
      this.view = view;
      this.engine = engine;
    }
  }

  private static void applyParams(LayoutParams params, List<Number> serializedParams) {
    if (serializedParams.get(0) != null) {
      params.gravity = serializedParams.get(0).intValue();
    }
    if (serializedParams.get(1) != null) {
      params.x = serializedParams.get(1).intValue();
    }
    if (serializedParams.get(2) != null) {
      params.y = serializedParams.get(2).intValue();
    }
    if (serializedParams.get(3) != null) {
      params.width = serializedParams.get(3).intValue();
    }
    if (serializedParams.get(4) != null) {
      params.height = serializedParams.get(4).intValue();
    }
  }

  private MethodChannel channel;
  private Context context;
  private ServicePluginBinding serviceBinding;
  private ActivityPluginBinding activityBinding;

  private WindowManager windowManager;

  private int nextHandle;
  private Map<Integer, Window> windows;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "overlay_window");
    channel.setMethodCallHandler(this);

    context = flutterPluginBinding.getApplicationContext();

    windowManager = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);

    windows = new HashMap<>();
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "createWindow": {
        final List<Number> arguments = call.arguments();
        final long entrypoint = arguments.get(0).longValue();
        final LayoutParams params = new LayoutParams(
            TYPE_SYSTEM_ALERT,
            FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        );
        applyParams(params, arguments.subList(1, 6));

        final Window window = new Window(
            new FlutterView(context, new FlutterSurfaceView(context, true)),
            new FlutterEngine(context));

        int handle = nextHandle++;
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
        }

        final LayoutParams params = (LayoutParams)window.view.getLayoutParams();
        applyParams(params, arguments.subList(1, 6));
        windowManager.updateViewLayout(window.view, params);

        result.success(null);

        break;
      }
      case "destroyWindow": {
        final int handle = call.arguments();
        final Window window = windows.remove(handle);

        if (window == null) {
          result.error("Argument exception", "No window for handle " + handle, null);
        }

        windowManager.removeView(window.view);

        window.engine.getLifecycleChannel().appIsInactive();
        window.engine.getLifecycleChannel().appIsPaused();
        window.engine.getLifecycleChannel().appIsDetached();

        if (serviceBinding != null) {
          window.engine.getServiceControlSurface().detachFromService();
        }
        if (activityBinding != null) {
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

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    windows = null;
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
    for (final Window window : windows.values()) {
      attachToService(window.engine);
    }
  }

  @Override
  public void onDetachedFromService() {
    for (final Window window : windows.values()) {
      window.engine.getServiceControlSurface().detachFromService();
    }
    serviceBinding = null;
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activityBinding = binding;
    for (final Window window : windows.values()) {
      attachToActivity(window.engine);
    }
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    for (final Window window : windows.values()) {
      window.engine.getActivityControlSurface().detachFromActivityForConfigChanges();
    }
    activityBinding = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public void onDetachedFromActivity() {
    for (final Window window : windows.values()) {
      window.engine.getActivityControlSurface().detachFromActivity();
    }
    activityBinding = null;
  }
}
