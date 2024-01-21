package io.baku.app_widget_host;

import android.appwidget.AppWidgetHost;
import android.appwidget.AppWidgetHostView;
import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

public class FlutterAppWidgetHostView implements PlatformView {
  public static final String PLATFORM_VIEW_TYPE = "io.baku.AppWidgetHost";

  public static class Factory extends PlatformViewFactory {
    private final AppWidgetHost appWidgetHost;
    private final AppWidgetManager appWidgetManager;

    public Factory(AppWidgetHost appWidgetHost, AppWidgetManager appWidgetManager) {
      super(StandardMessageCodec.INSTANCE);
      this.appWidgetHost = appWidgetHost;
      this.appWidgetManager = appWidgetManager;
    }

    @NonNull
    @Override
    public PlatformView create(@NonNull Context context, int id, @Nullable Object args) {
      if (args == null) {
        throw new IllegalArgumentException("Missing required app widget ID.");
      }

      final int appWidgetId = (int)args;
      final AppWidgetHostView view = appWidgetHost.createView(
          context, appWidgetId, appWidgetManager.getAppWidgetInfo(appWidgetId));
      view.setPadding(0, 0, 0, 0);
      return new FlutterAppWidgetHostView(view);
    }
  }

  private AppWidgetHostView view;

  FlutterAppWidgetHostView(@NonNull AppWidgetHostView view) {
    this.view = view;
  }

  @NonNull
  @Override
  public View getView() {
    return view;
  }

  @Override
  public void dispose() {
    view = null;
  }
}
