package io.baku.ride_device_policy;

import android.accessibilityservice.AccessibilityService;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;

import io.flutter.plugin.common.EventChannel.EventSink;

/**
 * This is a pared-down https://github.com/X-SLAYER/flutter_accessibility_service.
 */
public class RideAccessibilityService extends AccessibilityService {
  // The accessibility service seems to run in the same process as the Flutter app, which is super
  // convenient but seems too good to be true. Keep an eye on this.
  public static RideAccessibilityService instance;
  public static EventSink eventSink;

  @Override
  protected void onServiceConnected() {
    Log.i("ride_launcher", "A11y conntected.");
    synchronized (RideAccessibilityService.class) {
      instance = this;
      RideAccessibilityService.class.notifyAll();
    }
  }

  @Override
  public void onAccessibilityEvent(AccessibilityEvent event) {
    if (eventSink != null) {
      eventSink.success(event.getPackageName());
    }
  }

  @Override
  public void onInterrupt() {
  }
}
