import 'dart:async';

import 'package:app_widget_host/app_widget_host.dart';
import 'package:flutter/material.dart';

import '../core/client.dart';
import 'persistent_app_widget.dart';
import 'vehicle_controls.dart';

class BottomBarControls extends StatelessWidget {
  final ClientManager clientManager;
  const BottomBarControls({super.key, required this.clientManager});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Builder(
                  builder: (context) => TemperatureControls(
                    clientManager: clientManager,
                    mainAxisAlignment: MainAxisAlignment.start,
                    textStyle: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ClimateInfo(clientManager: clientManager),
                Expanded(
                  child: DriveInfo(clientManager: clientManager),
                ),
              ],
            ),
          ),
          const SizedBox(width: 96.0 + 2 * 12.0),
          Expanded(
            child: Row(
              children: [
                const Expanded(
                  child: PersistentAppWidget(
                    borderRadius: BorderRadius.all(Radius.circular(6.0)),
                    provider: ComponentName(
                      'com.spotify.music',
                      'com.spotify.widget.widget.SpotifyWidget',
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                VolumeControls(clientManager: clientManager),
              ],
            ),
          ),
        ],
      );
}

class ClimateInfo extends StatelessWidget {
  final ClientManager clientManager;
  const ClimateInfo({super.key, required this.clientManager});

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
        style: Theme.of(context).textTheme.titleMedium!,
        child: ListenableBuilder(
          listenable: clientManager,
          builder: (context, _) {
            final climate = clientManager.vehicle.climate;
            final exterior = climate.exterior, interior = climate.interior;
            return Padding(
              padding: exterior != null || interior != null
                  ? const EdgeInsets.only(left: 8.0, right: 12.0)
                  : EdgeInsets.zero,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (exterior != null)
                    Text('Ext: ${TemperatureControls.format(exterior)}'),
                  if (interior != null)
                    Text('Int: ${TemperatureControls.format(interior)}'),
                ],
              ),
            );
          },
        ),
      );
}

class DriveInfo extends StatelessWidget {
  final ClientManager clientManager;
  const DriveInfo({super.key, required this.clientManager});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: clientManager,
        builder: (context, _) {
          final drive = clientManager.vehicle.drive;

          late final DateTime eta;
          late final String timeToArrival;
          if (drive.minutesToArrival != null) {
            final dt = Duration(
              seconds:
                  (drive.minutesToArrival! * Duration.secondsPerMinute).toInt(),
            );
            eta = DateTime.now().add(dt);

            final days = dt.inDays,
                hours = dt.inHours % Duration.hoursPerDay,
                minutes = dt.inMinutes % Duration.minutesPerHour;

            timeToArrival = [
              if (days > 0) '$days d',
              if (hours > 0) '$hours hr',
              if (minutes > 0 || days == 0 && hours == 0) '$minutes min',
            ].join(' ');
          }

          late final String milesToArrival;
          if (drive.milesToArrival != null) {
            milesToArrival =
                '${drive.milesToArrival!.toStringAsFixed(drive.milesToArrival! >= 10 || drive.milesToArrival! < 0.1 ? 0 : 1)} mi';
          }

          final theme = Theme.of(context);

          return drive.destination == null &&
                  drive.milesToArrival == null &&
                  drive.minutesToArrival == null
              ? const SizedBox()
              : Card(
                  margin: const EdgeInsets.only(left: 8.0),
                  child: DefaultTextStyle(
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (drive.destination != null)
                            Text(
                              drive.destination!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (drive.minutesToArrival != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                EtaWidget(
                                  eta: eta,
                                  updateTimeout: const Duration(seconds: 20),
                                ),
                                Text(timeToArrival),
                                if (drive.milesToArrival != null)
                                  Text(milesToArrival),
                              ],
                            ),
                          if (drive.minutesToArrival == null &&
                              drive.milesToArrival != null)
                            Text('Distance to destination: $milesToArrival mi'),
                        ],
                      ),
                    ),
                  ),
                );
        },
      );
}

class EtaWidget extends StatefulWidget {
  final Duration updateTimeout;
  final DateTime eta;
  const EtaWidget({
    super.key,
    required this.eta,
    this.updateTimeout = Duration.zero,
  });

  @override
  State<StatefulWidget> createState() => _EtaWidgetState();
}

class _EtaWidgetState extends State<EtaWidget> {
  late Eta eta;
  DateTime get t => eta.value!;

  @override
  void initState() {
    super.initState();
    eta = Eta(updateTimeout: widget.updateTimeout)..value = widget.eta;
  }

  @override
  void didUpdateWidget(covariant EtaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.updateTimeout != oldWidget.updateTimeout) {
      eta.dispose();
      eta = Eta(updateTimeout: widget.updateTimeout);
    }
    eta.value = widget.eta;
  }

  @override
  void dispose() {
    eta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: eta,
        builder: (context, _) => Text('ETA: '
            '${(t.hour - 1) % 12 + 1}:'
            '${t.minute.toString().padLeft(2, '0')} '
            '${t.hour < 12 ? 'a.m.' : 'p.m.'}'),
      );
}

class Eta extends ChangeNotifier {
  final Duration updateTimeout;
  DateTime? _value;
  DateTime? get value => _value;
  set value(DateTime? value) {
    _timer?.cancel();

    if (value != _value) {
      _value = value;
      notifyListeners();
    }

    if (value != null) {
      // Accumulated error is acceptable.
      void startJustified() {
        final nextMinute = _value!
            .copyWith(
              minute: _value!.minute + 1,
              second: 0,
              millisecond: 0,
              microsecond: 0,
            )
            .difference(_value!);

        _timer = Timer(nextMinute, () {
          _value = _value!.add(nextMinute);
          notifyListeners();

          _timer = Timer.periodic(
            const Duration(minutes: 1),
            (_) {
              _value = _value!.add(const Duration(minutes: 1));
              notifyListeners();
            },
          );
        });
      }

      if (updateTimeout == Duration.zero) {
        startJustified();
      } else {
        _timer = Timer(updateTimeout, () {
          _value = _value!.add(updateTimeout);
          notifyListeners();

          startJustified();
        });
      }
    }
  }

  Timer? _timer;

  Eta({this.updateTimeout = Duration.zero, DateTime? value}) {
    this.value = value;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
