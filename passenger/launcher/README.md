# ride_launcher

A new Flutter project.

## Provisioning

Fire tablets are particularly resistant to disabling the keyguard. To disable the lockscreen:

```shell
adb shell su -c sqlite3 /data/system/locksettings.db
UPDATE locksettings SET value = '1' WHERE name = 'lockscreen.disabled';
adb reboot
```

The base API level is 22. Things that didn't work:
* `KeyguardManager`: permission denied even if in manifest.
* `LayoutParams`: ignored.