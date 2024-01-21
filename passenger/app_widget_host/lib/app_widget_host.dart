import 'package:app_widget_host/app_widget_host_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class ComponentName {
  final String packageName, className;
  const ComponentName(this.packageName, this.className);
}

abstract class AppWidgetHost {
  const AppWidgetHost._();

  static Future<int> allocateAppWidgetId() =>
      AppWidgetHostPlatform.instance.allocateAppWidgetId();
  static Future<bool> bindAppWidgetIdIfAllowed(
          int appWidgetId, ComponentName provider) =>
      AppWidgetHostPlatform.instance
          .bindAppWidgetIdIfAllowed(appWidgetId, provider);
  static Future<bool> requestBindAppWidget(
          int appWidgetId, ComponentName provider) =>
      AppWidgetHostPlatform.instance
          .requestBindAppWidget(appWidgetId, provider);
  static Future<bool> configureAppWidget(int appWidgetId) =>
      AppWidgetHostPlatform.instance.configureAppWidget(appWidgetId);
  static Future<void> deleteAppWidgetId(int appWidgetId) =>
      AppWidgetHostPlatform.instance.deleteAppWidgetId(appWidgetId);
}

class AppWidgetHostView extends StatelessWidget {
  static const viewType = 'io.baku.AppWidgetHost';

  final int appWidgetId;

  const AppWidgetHostView({super.key, required this.appWidgetId});

  @override
  Widget build(BuildContext context) => PlatformViewLink(
        viewType: viewType,
        surfaceFactory: (context, controller) => AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const {},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        ),
        onCreatePlatformView: (params) =>
            PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: Directionality.of(context),
          creationParams: appWidgetId,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
              ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
              ..create(),
      );
}
