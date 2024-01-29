import 'package:app_widget_host/app_widget_host.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_widget_host_platform_interface.dart';

/// An implementation of [AppWidgetHostPlatform] that uses method channels.
class MethodChannelAppWidgetHost extends AppWidgetHostPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('app_widget_host');

  @override
  Future<int> allocateAppWidgetId() async =>
      await methodChannel.invokeMethod('allocateAppWidgetId');
  @override
  Future<bool> bindAppWidgetIdIfAllowed(
          int appWidgetId, ComponentName provider) async =>
      await methodChannel.invokeMethod('bindAppWidgetIdIfAllowed', {
        'appWidgetId': appWidgetId,
        'packageName': provider.packageName,
        'className': provider.className,
      });
  @override
  Future<bool> requestBindAppWidget(
          int appWidgetId, ComponentName provider) async =>
      await methodChannel.invokeMethod('requestBindAppWidget', {
        'appWidgetId': appWidgetId,
        'packageName': provider.packageName,
        'className': provider.className,
      });
  @override
  Future<bool> configureAppWidget(int appWidgetId) async =>
      await methodChannel.invokeMethod('configureAppWidget', appWidgetId);
  @override
  Future<bool> checkAppWidget(int appWidgetId) async =>
      await methodChannel.invokeMethod('checkAppWidget', appWidgetId);
  @override
  Future<void> deleteAppWidgetId(int appWidgetId) async =>
      await methodChannel.invokeMethod('deleteAppWidgetId', appWidgetId);
}
