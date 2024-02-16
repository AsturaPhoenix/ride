import 'dart:math';

import 'package:flutter/material.dart';

import '../core/client.dart';
import 'numeric_control.dart';

final overlayTheme = ThemeData.dark(useMaterial3: true);

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: overlayTheme,
      home: DefaultTextStyle(
        style: overlayTheme.textTheme.labelLarge!.copyWith(fontSize: 22.0),
        child: child,
      ),
    );

class ClimateControls extends StatelessWidget {
  // The car seems to use a fudged Celcius-to-Fahrenheit conversion.
  static String format(double temperature) =>
      '${(temperature * 2 + 28).round()}°F';

  @pragma('vm:entry-point')
  static Future<void> main(_) async {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(
      _wrap(
        ClimateControls(clientManager: await ClientManager.initialize()),
      ),
    );
  }

  final ClientManager clientManager;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  final TextStyle? textStyle;
  const ClimateControls({
    super.key,
    required this.clientManager,
    this.mainAxisSize = MainAxisSize.max,
    this.mainAxisAlignment = MainAxisAlignment.spaceEvenly,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: clientManager,
        builder: (context, _) {
          final climate = clientManager.vehicle.climate;
          final setting = climate.setting.value;

          final min = climate.meta.min ?? double.negativeInfinity,
              max = climate.meta.max ?? double.infinity;

          return NumericControl(
            mainAxisSize: mainAxisSize,
            mainAxisAlignment: mainAxisAlignment,
            value: setting,
            min: min,
            max: max,
            step: 0.5, // Tesla uses a .5 degree mapping to Fahrenheit.
            onChange: clientManager.setClimate,
            child: AspectRatio(
              aspectRatio: 1,
              child: Center(
                child: Text(
                  setting == null
                      ? '??'
                      : setting == min
                          ? 'LO'
                          : setting == max
                              ? 'HI' // Actually, the car ends up snapping to HI
                              // a degree early, e.g. max = 28 C, but setting to
                              // 27 snaps to 28.
                              : format(setting),
                  style: textStyle,
                ),
              ),
            ),
          );
        },
      );
}

class VolumeControls extends StatelessWidget {
  @pragma('vm:entry-point')
  static Future<void> main(_) async {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(
      _wrap(VolumeControls(clientManager: await ClientManager.initialize())),
    );
  }

  final ClientManager clientManager;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  const VolumeControls({
    super.key,
    required this.clientManager,
    this.mainAxisSize = MainAxisSize.max,
    this.mainAxisAlignment = MainAxisAlignment.spaceEvenly,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: clientManager,
        builder: (context, _) {
          final volume = clientManager.vehicle.volume;
          final setting = volume.setting.value;

          final step = volume.meta.step ?? 1.0,
              max = volume.meta.max ?? double.infinity;

          final normalizedVolume = setting == null ? 0.5 : setting / max;

          return NumericControl(
            mainAxisSize: mainAxisSize,
            mainAxisAlignment: mainAxisAlignment,
            value: setting,
            min: 0.0,
            max: max,
            step: step,
            onChange: clientManager.setVolume,
            child: AspectRatio(
              aspectRatio: 1.0,
              child: CustomPaint(
                painter: VolumePainter(
                  primaryColor:
                      DefaultTextStyle.of(context).style.color ?? Colors.black,
                  normalizedVolume: normalizedVolume,
                ),
                size: Size.infinite,
              ),
            ),
          );
        },
      );
}

class VolumePainter extends CustomPainter {
  static final speaker = Path()
    ..addPolygon(
      const [
        Offset(-1 / 3, -1 / 6),
        Offset(-5 / 24, -1 / 6),
        Offset(0, -1 / 3),
        Offset(0, 1 / 3),
        Offset(-5 / 24, 1 / 6),
        Offset(-1 / 3, 1 / 6),
      ],
      true,
    );
  static const arcLength = 2 * pi / 3;

  final Color primaryColor;
  final Color? secondaryColor;
  final double normalizedVolume;
  const VolumePainter({
    required this.primaryColor,
    this.secondaryColor,
    required this.normalizedVolume,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = primaryColor;

    canvas
      ..scale(size.width, size.height)
      ..translate(.475, .5)
      ..drawPath(speaker, paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / 24
      ..strokeCap = StrokeCap.round;

    canvas.translate(.05, 0);

    for (int i = 1; i <= 3; ++i) {
      paint.color = Color.lerp(
        secondaryColor,
        primaryColor,
        Interval((i - 1) / 4, (i + 1) / 4).transform(normalizedVolume),
      )!;

      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: i / 9),
        -arcLength / 2,
        arcLength,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant VolumePainter oldDelegate) =>
      normalizedVolume != oldDelegate.normalizedVolume ||
      primaryColor != oldDelegate.primaryColor ||
      secondaryColor != oldDelegate.secondaryColor;
}
