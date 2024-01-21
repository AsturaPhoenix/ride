import 'package:app_widget_host/app_widget_host.dart';
import 'package:flutter/material.dart';
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

enum _BindingState { unbound, bound, configured }

class _PersistentAppWidgetState extends State<PersistentAppWidget> {
  static const keyPrefix = 'PersistentAppWidget';

  String get tagKey =>
      '$keyPrefix:${widget.tag ?? '${widget.provider.packageName}/${widget.provider.className}'}';
  String get appWidgetIdKey => '$tagKey:appWidgetId';
  String get bindingStateKey => '$tagKey:bindingStateKey';

  late final SharedPreferences sharedPreferences;
  late final int appWidgetId;
  _BindingState bindingState = _BindingState.unbound;
  bool bindInProgress = true;

  @override
  void initState() {
    super.initState();

    () async {
      sharedPreferences = await SharedPreferences.getInstance();
      if (!mounted) return;

      int? idResult = sharedPreferences.getInt(appWidgetIdKey);
      if (idResult == null) {
        idResult = await AppWidgetHost.allocateAppWidgetId();
        sharedPreferences.setInt(appWidgetIdKey, idResult);
        if (!mounted) return;
      }

      final bindingStateIndex = sharedPreferences.getInt(bindingStateKey);

      setState(() {
        appWidgetId = idResult!;
        bindingState = bindingStateIndex == null
            ? _BindingState.unbound
            : _BindingState.values[bindingStateIndex];
      });

      await bind();
    }();
  }

  Future<void> bind() async {
    setState(() => bindInProgress = true);

    switch (bindingState) {
      case _BindingState.unbound:
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

        sharedPreferences.setInt(bindingStateKey, _BindingState.bound.index);
        if (!mounted) return;
        setState(() => bindingState = _BindingState.bound);
        continue a;
      a:
      case _BindingState.bound:
        if (await AppWidgetHost.configureAppWidget(appWidgetId)) {
          sharedPreferences.setInt(
            bindingStateKey,
            _BindingState.configured.index,
          );
          if (!mounted) return;
          setState(() {
            bindingState = _BindingState.configured;
          });
        }
        continue b;
      b:
      default:
        if (mounted) {
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
              child: AppWidgetHostView(appWidgetId: appWidgetId),
            )
          : Center(
              child: OutlinedButton(
                onPressed: bind,
                child: const Text('Reload widget'),
              ),
            );
}
