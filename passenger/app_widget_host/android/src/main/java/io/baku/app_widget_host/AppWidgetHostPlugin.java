package io.baku.app_widget_host;

import android.app.Activity;
import android.appwidget.AppWidgetHost;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProviderInfo;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Objects;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;

/**
 * AppWidgetHostPlugin
 */
public class AppWidgetHostPlugin implements
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    ActivityResultListener {
  public static final int
      APP_WIDGET_HOST_ID = 0,
      REQUEST_BIND_APPWIDGET = 0x10,
      REQUEST_CONFIGURE_APPWIDGET = 0x11;
  // TODO: Make request range configurable to handle conflicts with other plugins.

  private MethodChannel channel;
  private Context context;
  private ActivityPluginBinding activityBinding;
  private AppWidgetManager appWidgetManager;
  private AppWidgetHost appWidgetHost;

  private Result activityResult;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), "app_widget_host");
    channel.setMethodCallHandler(this);

    context = binding.getApplicationContext();
    appWidgetHost = new AppWidgetHost(context, APP_WIDGET_HOST_ID);
    appWidgetManager = AppWidgetManager.getInstance(context);

    binding
        .getPlatformViewRegistry()
        .registerViewFactory(
            FlutterAppWidgetHostView.PLATFORM_VIEW_TYPE,
            new FlutterAppWidgetHostView.Factory(appWidgetHost, appWidgetManager));
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activityBinding = binding;
    binding.addActivityResultListener(this);
    appWidgetHost.startListening();
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
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "allocateAppWidgetId": {
        result.success(appWidgetHost.allocateAppWidgetId());
        break;
      }
      case "bindAppWidgetIdIfAllowed":
        result.success(appWidgetManager.bindAppWidgetIdIfAllowed(
            call.argument("appWidgetId"),
            new ComponentName(
                call.<String>argument("packageName"),
                call.argument("className"))
        ));
        break;
      case "requestBindAppWidget": {
        final Intent intent = new Intent(AppWidgetManager.ACTION_APPWIDGET_BIND);
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,
            call.<Number>argument("appWidgetId"));
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, new ComponentName(
            call.<String>argument("packageName"),
            call.argument("className")));

        if (activityResult != null) {
          throw new IllegalStateException("Unexpected uncompleted activity result.");
        }
        activityResult = result;
        activityBinding.getActivity().startActivityForResult(intent, REQUEST_BIND_APPWIDGET);
        break;
      }
      case "configureAppWidget": {
        final int appWidgetId = call.arguments();
        final AppWidgetProviderInfo info = appWidgetManager.getAppWidgetInfo(appWidgetId);
        if (info.configure == null) {
          result.success(true);
        } else {
          if (activityResult != null) {
            throw new IllegalStateException("Unexpected uncompleted activity result.");
          }
          activityResult = result;
          appWidgetHost.startAppWidgetConfigureActivityForResult(
              activityBinding.getActivity(),
              appWidgetId,
              0,
              REQUEST_CONFIGURE_APPWIDGET,
              null);
        }
        break;
      }
      case "checkAppWidget": {
        final int appWidgetId = call.arguments();
        result.success(appWidgetManager.getAppWidgetInfo(appWidgetId) != null);
        break;
      }
      case "deleteAppWidgetId": {
        appWidgetHost.deleteAppWidgetId(call.arguments());
        result.success(null);
        break;
      }
      default:
        result.notImplemented();
    }
  }

  @Override
  public boolean onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
    switch (requestCode) {
      case REQUEST_BIND_APPWIDGET:
      case REQUEST_CONFIGURE_APPWIDGET:
        switch (resultCode) {
          case Activity.RESULT_OK:
            activityResult.success(true);
            break;
          case Activity.RESULT_CANCELED:
            activityResult.success(false);
            break;
          default:
            activityResult.error(
                Integer.toString(resultCode),
                "Exceptional activity result.",
                Objects.toString(data));
            break;
        }
        activityResult = null;
        return true;
      default:
        return false;
    }
  }

  @Override
  public void onDetachedFromActivity() {
    if (activityResult != null) {
      activityResult.error("failed", "Activity detached.", null);
      activityResult = null;
    }

    appWidgetHost.stopListening();
    activityBinding.removeActivityResultListener(this);
    activityBinding = null;
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    appWidgetHost.deleteHost();
    appWidgetHost = null;
    channel.setMethodCallHandler(null);
  }
}
