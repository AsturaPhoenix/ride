package io.baku.ride_device_policy;

import android.accessibilityservice.AccessibilityService;
import android.view.accessibility.AccessibilityEvent;

import io.flutter.plugin.common.EventChannel.EventSink;

/**
 * This is a pared-down https://github.com/X-SLAYER/flutter_accessibility_service.
 */
public class RideAccessibilityService extends AccessibilityService {
  // The accessibility service seems to run in the same process as the Flutter app, which is super
  // convenient but seems too good to be true. Keep an eye on this.
  public static EventSink eventSink;

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
