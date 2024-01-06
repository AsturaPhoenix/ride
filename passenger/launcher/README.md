# RIDE Launcher

Passenger UI for the Rideshare In-Drive Experience.

## Provisioning

To disable the keyguard/lockscreen and status bar, we need to toggle `device_provisioned` to `'0'`. However, this can also disable developer options and eventually lock us out of ADB. A 'Toggle provisioned' button is provided in the nav tray while the device is not connected to the server.

Immediately after a reboot, the status bar may show some nonfunctional UI. After dismissing it, it will show a more minimal UI.

The base API level is 22.

### Keyguard

The keyguard should be disabled after reboot when `device_provisioned` is `'0'`. One thing we tried earlier was:

```shell
adb shell su -c sqlite3 /data/system/locksettings.db
UPDATE locksettings SET value = '1' WHERE name = 'lockscreen.disabled';
adb reboot
```

However, this did not work after a second factory reset.

Other things that didn't work:
* `KeyguardManager`: permission denied even if in manifest.
* `LayoutParams`: ignored.

### Status bar

Similarly, the status bar management APIs are unavailable in API level 22. Lock tasks are a very soft lock, and setting lock-task packages fails even with `device_owner.xml`.
