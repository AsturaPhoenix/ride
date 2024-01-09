import 'dart:ui';

import 'package:flutter/services.dart';

import 'overlay_window.dart';
import 'overlay_window_platform_interface.dart';

@pragma('vm:entry-point')
void overlayMain(List<String> args) => PluginUtilities.getCallbackFromHandle(
    CallbackHandle.fromRawHandle(int.parse(args.first)))!();

/// An implementation of [RideDevicePolicyPlatform] that uses method channels.
class MethodChannelOverlayWindow extends OverlayWindowPlatform {
  static const methodChannel = MethodChannel('overlay_window');

  @override
  Future<int> createWindow(
      void Function() entrypoint, WindowParams params) async {
    final entrypointHandle = PluginUtilities.getCallbackHandle(entrypoint);
    if (entrypointHandle == null) {
      throw ArgumentError(
          'Entrypoint must be a top-level or static function', 'entrypoint');
    }
    return await methodChannel.invokeMethod('createWindow', [
      entrypointHandle.toRawHandle(),
      params.gravity,
      params.x,
      params.y,
      params.width,
      params.height,
    ]) as int;
  }

  @override
  Future<void> destroyWindow(int handle) =>
      methodChannel.invokeMethod('destroyWindow', handle);
}
