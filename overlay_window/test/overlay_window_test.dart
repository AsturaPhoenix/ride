import 'package:flutter_test/flutter_test.dart';
import 'package:overlay_window/overlay_window.dart';
import 'package:overlay_window/overlay_window_method_channel.dart';
import 'package:overlay_window/overlay_window_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeOverlayWindowPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements OverlayWindowPlatform {
  int nextHandle = 0;
  final windows = <int, WindowParams>{};

  @override
  Future<int> createWindow(
      void Function() entrypoint, WindowParams params) async {
    final handle = nextHandle++;
    windows[handle] = params;
    entrypoint();
    return handle;
  }

  @override
  Future<void> destroyWindow(int handle) async => windows.remove(handle);
}

void main() {
  final OverlayWindowPlatform initialPlatform = OverlayWindowPlatform.instance;

  test('$MethodChannelOverlayWindow is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelOverlayWindow>());
  });

  group('fake tests', () {
    setUp(() => OverlayWindowPlatform.instance = FakeOverlayWindowPlatform());
  });
}
