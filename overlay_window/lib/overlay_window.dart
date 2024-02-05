import 'overlay_window_platform_interface.dart';

abstract class Gravity {
  static const noGravity = 0x0000, axisSpecified = 0x0001;

  /// Raw bit controlling how the left/top edge is placed.
  static const axisPullBefore = 0x0002;

  /// Raw bit controlling how the right/bottom edge is placed.
  static const axisPullAfter = 0x0004;

  /// Raw bit controlling whether the right/bottom edge is clipped to its
  /// container, based on the gravity direction being applied.
  static const axisClip = 0x0008;

  /// Bits defining the horizontal axis.
  static const axisXShift = 0;

  /// Bits defining the vertical axis.
  static const axisYShift = 4;

  /// Push object to the top of its container, not changing its size.
  static const top = (axisPullBefore | axisSpecified) << axisYShift;

  /// Push object to the bottom of its container, not changing its size.
  static const bottom = (axisPullAfter | axisSpecified) << axisYShift;

  /// Push object to the left of its container, not changing its size.
  static const left = (axisPullBefore | axisSpecified) << axisXShift;

  /// Push object to the right of its container, not changing its size.
  static const right = (axisPullAfter | axisSpecified) << axisXShift;

  /// Place object in the vertical center of its container, not changing its
  /// size.
  static const centerVertical = axisSpecified << axisYShift;

  /// Grow the vertical size of the object if needed so it completely fills
  /// its container.
  static const fillVertical = top | bottom;

  /// Place object in the horizontal center of its container, not changing
  /// its size.
  static const centerHorizontal = axisSpecified << axisXShift;

  /// Grow the horizontal size of the object if needed so it completely
  /// fills its container.
  static const fillHorizontal = left | right;

  /// Place the object in the center of its container in both the vertical
  /// and horizontal axis, not changing its size.
  static const center = centerVertical | centerHorizontal;

  /// Grow the horizontal and vertical size of the object if needed so it
  /// completely fills its container.
  static const fill = fillVertical | fillHorizontal;

  /// Flag to clip the edges of the object to its container along the
  /// vertical axis.
  static const clipVertical = axisClip << axisYShift;

  /// Flag to clip the edges of the object to its container along the
  /// horizontal axis.
  static const clipHorizontal = axisClip << axisXShift;

  /// Raw bit controlling whether the layout direction is relative or not
  /// (start/end instead of absolute left/right).
  static const relativeLayoutDirection = 0x00800000;

  /// Binary mask to get the absolute horizontal gravity of a gravity.
  static const horizontalGravityMask =
      (axisSpecified | axisPullBefore | axisPullAfter) << axisXShift;

  /// Binary mask to get the vertical gravity of a gravity.
  static const verticalGravityMask =
      (axisSpecified | axisPullBefore | axisPullAfter) << axisYShift;

  /// Special constant to enable clipping to an overall display along the
  /// vertical dimension.  This is not applied by default by
  /// {@link #apply(int, int, int, Rect, int, int, Rect)}, you must do so
  /// yourself by calling {@link #applyDisplay}.
  static const displayClipVertical = 0x10000000;

  /// Special constant to enable clipping to an overall display along the
  /// horizontal dimension.  This is not applied by default by
  /// {@link #apply(int, int, int, Rect, int, int, Rect)}, you must do so
  /// yourself by calling {@link #applyDisplay}.
  static const displayClipHorizontal = 0x01000000;

  /// Push object to x-axis position at the start of its container, not
  /// changing its size.
  static const start = relativeLayoutDirection | left;

  /// Push object to x-axis position at the end of its container, not
  /// changing its size.
  static const end = relativeLayoutDirection | right;

  /// Binary mask for the horizontal gravity and script specific direction
  /// bit.
  static const relativeHorizontalGravityMask = start | end;

  Gravity._();
}

class Flag {
  /// Window flag: this window won't ever get key input focus, so the user
  /// cannot send key or other button events to it. Those will instead go to
  /// whatever focusable window is behind it. This flag will also enable
  /// {@link #FLAG_NOT_TOUCH_MODAL} whether or not that is explicitly set.
  ///
  /// Setting this flag also implies that the window will not need to interact
  /// with a soft input method, so it will be Z-ordered and positioned
  /// independently of any active input method (typically this means it gets
  /// Z-ordered on top of the input method, so it can use the full screen for
  /// its content and cover the input method if needed. You can use
  /// {@link #FLAG_ALT_FOCUSABLE_IM} to modify this behavior.
  static const notFocusable = 0x00000008;

  /// Window flag: even when this window is focusable (its
  /// {@link #FLAG_NOT_FOCUSABLE} is not set), allow any pointer events outside
  /// of the window to be sent to the windows behind it.  Otherwise it will
  /// consume all pointer events itself, regardless of whether they are inside
  /// of the window.
  static const notTouchModal = 0x00000020;

  /// Window flag for attached windows: Place the window within the entire
  /// screen, ignoring any constraints from the parent window.
  ///
  /// Note: on displays that have a {@link DisplayCutout}, the window may be
  /// placed such that it avoids the {@link DisplayCutout} area if necessary
  /// according to the {@link #layoutInDisplayCutoutMode}.
  static const layoutInScreen = 0x00000100;

  /// Window flag: allow window to extend outside of the screen.
  static const layoutNoLimits = 0x00000200;

  /// Window flag: hide all screen decorations (such as the status bar) while
  /// this window is displayed. This allows the window to use the entire display
  /// space for itself--the status bar will be hidden when an app window with
  /// this flag set is on the top layer. A fullscreen window will ignore a value
  /// of {@link #SOFT_INPUT_ADJUST_RESIZE} for the window's
  /// {@link #softInputMode} field; the window will stay fullscreen and will not
  /// resize.
  ///
  /// This flag can be controlled in your theme through the
  /// {@link android.R.attr#windowFullscreen} attribute; this attribute is
  /// automatically set for you in the standard fullscreen themes such as
  /// {@link android.R.style#Theme_NoTitleBar_Fullscreen},
  /// {@link android.R.style#Theme_Black_NoTitleBar_Fullscreen},
  /// {@link android.R.style#Theme_Light_NoTitleBar_Fullscreen},
  /// {@link android.R.style#Theme_Holo_NoActionBar_Fullscreen},
  /// {@link android.R.style#Theme_Holo_Light_NoActionBar_Fullscreen},
  /// {@link android.R.style#Theme_DeviceDefault_NoActionBar_Fullscreen}, and
  /// {@link android.R.style#Theme_DeviceDefault_Light_NoActionBar_Fullscreen}.
  static const fullscreen = 0x00000400;

  /// Window flag: a special option only for use in combination with
  /// FLAG_LAYOUT_IN_SCREEN. When requesting layout in the screen your window
  /// may appear on top of or behind screen decorations such as the status bar.
  /// By also including this flag, the window manager will report the inset
  /// rectangle needed to ensure your content is not covered by screen
  /// decorations. This flag is normally set for you by Window as described in
  /// Window#setFlags
  static const layoutInsetDecor = 0x00010000;

  /// Flag indicating that this Window is responsible for drawing the background
  /// for the system bars. If set, the system bars are drawn with a transparent
  /// background and the corresponding areas in this window are filled with the
  /// colors specified in {@link Window#getStatusBarColor()} and
  /// {@link Window#getNavigationBarColor()}.
  static const drawsSystemBarBackgrounds = 0x80000000;

  Flag._();
}

class WindowParams {
  static const matchParent = -1, wrapContent = -2;

  final int? flags;
  final int? gravity;
  final int? x, y, width, height;

  const WindowParams({
    this.flags,
    this.gravity,
    this.x,
    this.y,
    this.width,
    this.height,
  });
}

typedef Entrypoint = void Function(OverlayWindow window);

class OverlayWindow {
  /// This view is visible.
  /// Use with {@link #setVisibility} and
  /// <a href="#attr_android:visibility">{@code android:visibility}.
  static const visible = 0x00000000;

  /// This view is invisible, but it still takes up space for layout purposes.
  /// Use with {@link #setVisibility} and
  /// <a href="#attr_android:visibility">{@code android:visibility}.
  static const invisible = 0x00000004;

  /// This view is invisible, and it doesn't take any space for layout
  /// purposes. Use with {@link #setVisibility} and
  /// <a href="#attr_android:visibility">{@code android:visibility}.
  static const gone = 0x00000008;

  final int _handle;
  OverlayWindow.forHandle(this._handle);

  Future<void> update(WindowParams params) =>
      OverlayWindowPlatform.instance.updateWindow(_handle, params);

  Future<void> setVisibility(int visibility) =>
      OverlayWindowPlatform.instance.setVisibility(_handle, visibility);

  Future<void> destroy() =>
      OverlayWindowPlatform.instance.destroyWindow(_handle);

  static Future<bool> requestPermissions() =>
      OverlayWindowPlatform.instance.requestPermissions();
  static Future<bool> hasPermissions() =>
      OverlayWindowPlatform.instance.hasPermissions();

  static Future<OverlayWindow> create(
          Entrypoint entrypoint, WindowParams params) async =>
      OverlayWindow.forHandle(await OverlayWindowPlatform.instance
          .createWindow(entrypoint, params));
}
