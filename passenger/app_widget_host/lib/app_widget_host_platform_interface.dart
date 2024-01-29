import 'package:app_widget_host/app_widget_host.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'app_widget_host_method_channel.dart';

abstract class AppWidgetHostPlatform extends PlatformInterface {
  /// Constructs a AppWidgetHostPlatform.
  AppWidgetHostPlatform() : super(token: _token);

  static final Object _token = Object();

  static AppWidgetHostPlatform _instance = MethodChannelAppWidgetHost();

  /// The default instance of [AppWidgetHostPlatform] to use.
  ///
  /// Defaults to [MethodChannelAppWidgetHost].
  static AppWidgetHostPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AppWidgetHostPlatform] when
  /// they register themselves.
  static set instance(AppWidgetHostPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<int> allocateAppWidgetId();
  Future<bool> bindAppWidgetIdIfAllowed(
      int appWidgetId, ComponentName provider);
  Future<bool> requestBindAppWidget(int appWidgetId, ComponentName provider);
  Future<bool> configureAppWidget(int appWidgetId);
  Future<bool> checkAppWidget(int appWidgetId);
  Future<void> deleteAppWidgetId(int appWidgetId);
}
