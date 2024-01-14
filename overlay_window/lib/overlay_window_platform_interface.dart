import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'overlay_window.dart';
import 'overlay_window_method_channel.dart';

enum WindowState {
  detached,
  resumed,
  inactive,
  hidden,
  paused,
}

abstract class OverlayWindowPlatform extends PlatformInterface {
  /// Constructs a OverlayWindowPlatform.
  OverlayWindowPlatform() : super(token: _token);

  static final Object _token = Object();

  static OverlayWindowPlatform _instance = MethodChannelOverlayWindow();

  /// The default instance of [OverlayWindowPlatform] to use.
  ///
  /// Defaults to [MethodChannelOverlayWindow].
  static OverlayWindowPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OverlayWindowPlatform] when
  /// they register themselves.
  static set instance(OverlayWindowPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<int> createWindow(Entrypoint entrypoint, WindowParams params);
  Future<void> updateWindow(int handle, WindowParams params);
  Future<void> setVisibility(int handle, int visibility);
  Future<void> destroyWindow(int handle);
}
