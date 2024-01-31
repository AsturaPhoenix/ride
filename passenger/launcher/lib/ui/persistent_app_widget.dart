import 'package:app_widget_host/app_widget_host.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/platform.dart' as platform;

class PersistentAppWidget extends StatefulWidget {
  final String? tag;
  final ComponentName provider;
  final BorderRadius borderRadius;

  const PersistentAppWidget({
    super.key,
    this.tag,
    required this.provider,
    this.borderRadius = const BorderRadius.all(Radius.circular(8.0)),
  });

  @override
  State<StatefulWidget> createState() => _PersistentAppWidgetState();
}

enum _BindingState { initial, allocated, bound, configured }

class _PersistentAppWidgetState extends State<PersistentAppWidget> {
  static const keyPrefix = 'PersistentAppWidget';

  String get tagKey =>
      '$keyPrefix:${widget.tag ?? '${widget.provider.packageName}/${widget.provider.className}'}';
  String get appWidgetIdKey => '$tagKey:appWidgetId';
  String get bindingStateKey => '$tagKey:bindingStateKey';

  late final SharedPreferences sharedPreferences;
  late int appWidgetId;
  _BindingState bindingState = _BindingState.initial;

  /// State modifications are hidden behind a spinner while this is true, so
  /// there's no need to setState for them.
  bool bindInProgress = true;

  @override
  void initState() {
    super.initState();

    () async {
      sharedPreferences = await SharedPreferences.getInstance();
      final idResult = sharedPreferences.getInt(appWidgetIdKey);
      if (idResult != null) {
        appWidgetId = idResult;
      }
      final bindingStateIndex = sharedPreferences.getInt(bindingStateKey);
      bindingState = bindingStateIndex == null || idResult == null
          ? _BindingState.initial
          : _BindingState.values[bindingStateIndex];

      if (mounted) {
        await bind();
      }
    }();
  }

  Future<void> bind() async {
    setState(() => bindInProgress = true);

    void setBindingState(_BindingState value) {
      sharedPreferences.setInt(bindingStateKey, value.index);
      bindingState = value;
    }

    switch (bindingState) {
      restart:
      case _BindingState.initial:
        appWidgetId = await AppWidgetHost.allocateAppWidgetId();
        if (!mounted) return;

        sharedPreferences.setInt(appWidgetIdKey, appWidgetId);
        setBindingState(_BindingState.allocated);
        continue a;
      a:
      case _BindingState.allocated:
        if (!await AppWidgetHost.bindAppWidgetIdIfAllowed(
          appWidgetId,
          widget.provider,
        )) {
          /// Fire OS doesn't seem to have a UI for granting app widget binding
          /// permissions, so we have to go over its head a little.
          await platform.run(
            'su',
            [
              '-c',
              'appwidget',
              'grantbind',
              '--package',
              'io.baku.ride_launcher',
              '--user',
              '0',
            ],
          );
          if (!await AppWidgetHost.bindAppWidgetIdIfAllowed(
            appWidgetId,
            widget.provider,
          )) {
            // Give up for now.
            if (mounted) {
              setState(() => bindInProgress = false);
            }
            return;
          }
        }

        if (!mounted) return;
        setBindingState(_BindingState.bound);
        continue b;
      b:
      case _BindingState.bound:
        try {
          if (await AppWidgetHost.configureAppWidget(appWidgetId)) {
            sharedPreferences.setInt(
              bindingStateKey,
              _BindingState.configured.index,
            );
            if (!mounted) return;
            setBindingState(_BindingState.configured);
          }
          if (!mounted) return;
          continue c;
        } on PlatformException {
          if (!mounted) return;
          setBindingState(_BindingState.initial);
          continue restart;
        }
      c:
      default:
        if (!await AppWidgetHost.checkAppWidget(appWidgetId)) {
          if (!mounted) return;
          setBindingState(_BindingState.initial);
          continue restart;
        } else {
          if (!mounted) return;
          setState(() => bindInProgress = false);
        }
    }
  }

  @override
  Widget build(BuildContext context) => bindInProgress
      ? const Center(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: CircularProgressIndicator(),
          ),
        )
      : bindingState == _BindingState.configured
          ? ClipRRect(
              borderRadius: widget.borderRadius,
              child: kIsWeb
                  ? ColoredBox(
                      color: Colors.grey.shade800,
                      child: const SizedBox.expand(),
                    )
                  : AppWidgetHostView(appWidgetId: appWidgetId),
            )
          : Center(
              child: OutlinedButton(
                onPressed: bind,
                child: const Text('Reload widget'),
              ),
            );
}
