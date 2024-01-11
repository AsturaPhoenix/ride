import 'overlay_window_platform_interface.dart';

abstract class Gravity {
  static const noGravity = 0x0000,
      axisSpecified = 0x0001,

      /// Raw bit controlling how the left/top edge is placed.
      axisPullBefore = 0x0002,

      /// Raw bit controlling how the right/bottom edge is placed.
      axisPullAfter = 0x0004,

      /// Raw bit controlling whether the right/bottom edge is clipped to its
      /// container, based on the gravity direction being applied.
      axisClip = 0x0008,

      /// Bits defining the horizontal axis.
      axisXShift = 0,

      /// Bits defining the vertical axis.
      axisYShift = 4,

      /// Push object to the top of its container, not changing its size.
      top = (axisPullBefore | axisSpecified) << axisYShift,

      /// Push object to the bottom of its container, not changing its size.
      bottom = (axisPullAfter | axisSpecified) << axisYShift,

      /// Push object to the left of its container, not changing its size.
      left = (axisPullBefore | axisSpecified) << axisXShift,

      /// Push object to the right of its container, not changing its size.
      right = (axisPullAfter | axisSpecified) << axisXShift,

      /// Place object in the vertical center of its container, not changing its
      /// size.
      centerVertical = axisSpecified << axisYShift,

      /// Grow the vertical size of the object if needed so it completely fills
      /// its container.
      fillVertical = top | bottom,

      /// Place object in the horizontal center of its container, not changing
      /// its size.
      centerHorizontal = axisSpecified << axisXShift,

      /// Grow the horizontal size of the object if needed so it completely
      /// fills its container.
      fillHorizontal = left | right,

      /// Place the object in the center of its container in both the vertical
      /// and horizontal axis, not changing its size.
      center = centerVertical | centerHorizontal,

      /// Grow the horizontal and vertical size of the object if needed so it
      /// completely fills its container.
      fill = fillVertical | fillHorizontal,

      /// Flag to clip the edges of the object to its container along the
      /// vertical axis.
      clipVertical = axisClip << axisYShift,

      /// Flag to clip the edges of the object to its container along the
      /// horizontal axis.
      clipHorizontal = axisClip << axisXShift,

      /// Raw bit controlling whether the layout direction is relative or not
      /// (start/end instead of absolute left/right).
      relativeLayoutDirection = 0x00800000,

      /// Binary mask to get the absolute horizontal gravity of a gravity.
      horizontalGravityMask =
          (axisSpecified | axisPullBefore | axisPullAfter) << axisXShift,

      /// Binary mask to get the vertical gravity of a gravity.
      verticalGravityMask =
          (axisSpecified | axisPullBefore | axisPullAfter) << axisYShift,

      /// Special constant to enable clipping to an overall display along the
      /// vertical dimension.  This is not applied by default by
      /// {@link #apply(int, int, int, Rect, int, int, Rect)}, you must do so
      /// yourself by calling {@link #applyDisplay}.
      displayClipVertical = 0x10000000,

      /// Special constant to enable clipping to an overall display along the
      /// horizontal dimension.  This is not applied by default by
      /// {@link #apply(int, int, int, Rect, int, int, Rect)}, you must do so
      /// yourself by calling {@link #applyDisplay}.
      displayClipHorizontal = 0x01000000,

      /// Push object to x-axis position at the start of its container, not
      /// changing its size.
      start = relativeLayoutDirection | left,

      /// Push object to x-axis position at the end of its container, not
      /// changing its size.
      end = relativeLayoutDirection | right,

      /// Binary mask for the horizontal gravity and script specific direction
      /// bit.
      relativeHorizontalGravityMask = start | end;

  Gravity._();
}

class WindowParams {
  static const matchParent = -1, wrapContent = -2;

  final int? gravity;
  final int? x, y, width, height;

  const WindowParams({
    this.gravity,
    this.x,
    this.y,
    this.width,
    this.height,
  });
}

typedef Entrypoint = void Function(OverlayWindow window);

class OverlayWindow {
  final int _handle;
  OverlayWindow.forHandle(this._handle);

  Future<void> update(WindowParams params) =>
      OverlayWindowPlatform.instance.updateWindow(_handle, params);

  Future<void> destroy() =>
      OverlayWindowPlatform.instance.destroyWindow(_handle);

  static Future<OverlayWindow> create(
          Entrypoint entrypoint, WindowParams params) async =>
      OverlayWindow.forHandle(await OverlayWindowPlatform.instance
          .createWindow(entrypoint, params));
}
