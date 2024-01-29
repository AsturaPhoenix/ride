package io.baku.ride_launcher;

import android.content.Intent;
import android.os.Bundle;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.FutureTask;

import io.baku.overlay_window.OverlayWindowPlugin;
import io.baku.ride_device_policy.RideAccessibilityService;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;

public class MainActivity extends FlutterActivity implements StreamHandler {
  private EventChannel intentsChannel;
  private EventSink intents;

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    // Elevate OverlayWindowPlugin privileges to allow navigation bar overlays that respond to
    // touch.
    final FutureTask elevate = new FutureTask<>(() -> {
      synchronized (RideAccessibilityService.class) {
        while (RideAccessibilityService.instance == null) {
          RideAccessibilityService.class.wait();
        }
      }
      return RideAccessibilityService.instance;
    });
    OverlayWindowPlugin.accessibilityService = elevate;
    new Thread(elevate::run).start();
  }

  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);

    intentsChannel = new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "ride_launcher.intents");
    intentsChannel.setStreamHandler(this);
  }

  @Override
  protected void onDestroy() {
    intents.endOfStream();
    super.onDestroy();
  }

  @Override
  protected void onNewIntent(@NonNull Intent intent) {
    super.onNewIntent(intent);

    final Map<String, Object> event = new HashMap<>();
    event.put("action", intent.getAction());
    event.put("categories", new ArrayList<>(intent.getCategories()));

    intents.success(event);
  }

  @Override
  public void onListen(Object arguments, EventSink events) {
    intents = events;
  }

  @Override
  public void onCancel(Object arguments) {
    intents = null;
  }
}
