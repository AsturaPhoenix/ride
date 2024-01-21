import 'package:app_widget_host/app_widget_host.dart';
import 'package:app_widget_host/app_widget_host_platform_interface.dart';

class FakeAppWidgetHost extends AppWidgetHostPlatform {
  FakeAppWidgetHost();

  @override
  Future<int> allocateAppWidgetId() async => 0;

  @override
  Future<bool> bindAppWidgetIdIfAllowed(
    int appWidgetId,
    ComponentName provider,
  ) async =>
      false;

  @override
  Future<bool> requestBindAppWidget(
    int appWidgetId,
    ComponentName provider,
  ) async =>
      false;

  @override
  Future<bool> configureAppWidget(int appWidgetId) async => true;

  @override
  Future<void> deleteAppWidgetId(int appWidgetId) async {}
}
