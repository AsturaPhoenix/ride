import 'dart:ui';

import 'package:flutter/services.dart';

import 'overlay_window.dart';
import 'overlay_window_platform_interface.dart';

@pragma('vm:entry-point')
void overlayMain(List<String> args) => PluginUtilities.getCallbackFromHandle(
        CallbackHandle.fromRawHandle(int.parse(args[0])))!(
    OverlayWindow.forHandle(int.parse(args[1])));

/// An implementation of [RideDevicePolicyPlatform] that uses method channels.
class MethodChannelOverlayWindow extends OverlayWindowPlatform {
  static const methodChannel = MethodChannel('overlay_window');

  static List<int?> serializeParams(WindowParams params) => [
        params.flags,
        params.gravity,
        params.x,
        params.y,
        params.width,
        params.height,
      ];

  @override
  Future<bool> requestPermissions() async =>
      await methodChannel.invokeMethod('requestPermissions') as bool;

  @override
  Future<bool> hasPermissions() async =>
      await methodChannel.invokeMethod('hasPermissions') as bool;

  @override
  Future<int> createWindow(Entrypoint entrypoint, WindowParams params) async {
    final entrypointHandle = PluginUtilities.getCallbackHandle(entrypoint);
    if (entrypointHandle == null) {
      throw ArgumentError(
          'Entrypoint must be a top-level or static function', 'entrypoint');
    }
    return await methodChannel.invokeMethod('createWindow',
        [entrypointHandle.toRawHandle(), ...serializeParams(params)]) as int;
  }

  @override
  Future<void> updateWindow(int handle, WindowParams params) => methodChannel
      .invokeMethod('updateWindow', [handle, ...serializeParams(params)]);

  @override
  Future<void> setVisibility(int handle, int visibility) =>
      methodChannel.invokeMethod('setVisibility', [handle, visibility]);

  @override
  Future<void> destroyWindow(int handle) =>
      methodChannel.invokeMethod('destroyWindow', handle);
}
