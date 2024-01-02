# RIDE Launcher

Passenger UI for the Rideshare In-Drive Experience.

## Provisioning

### Keyguard

Fire tablets are particularly resistant to disabling the keyguard. To disable the lockscreen:

```shell
adb shell su -c sqlite3 /data/system/locksettings.db
UPDATE locksettings SET value = '1' WHERE name = 'lockscreen.disabled';
adb reboot
```

The base API level is 22. Things that didn't work:
* `KeyguardManager`: permission denied even if in manifest.
* `LayoutParams`: ignored.

### Status bar

Similarly, the status bar management APIs are unavailable in API level 22. Lock tasks are a very soft lock, and setting lock-task packages fails even with `device_owner.xml`. Luckily, we can disable the harmful bits of the status bar with

```shell
adb shell settings put global device_provisioned 0
```

However, this may not be 100% reliable, particularly immediately after a reboot.
