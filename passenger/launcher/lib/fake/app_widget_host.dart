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
      true;

  @override
  Future<bool> requestBindAppWidget(
    int appWidgetId,
    ComponentName provider,
  ) async =>
      true;

  @override
  Future<bool> configureAppWidget(int appWidgetId) async => true;

  @override
  Future<void> deleteAppWidgetId(int appWidgetId) async {}

  @override
  Future<bool> checkAppWidget(int appWidgetId) async => true;
}
