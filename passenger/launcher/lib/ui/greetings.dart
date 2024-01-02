import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/greetings_config.dart' as greetings;
import '../core/random_cycler.dart';

class GreetingsController extends ChangeNotifier {
  void reload() => notifyListeners();
}

class Greetings extends StatefulWidget {
  final GreetingsController? controller;
  final SlideTiming timing;

  const Greetings({
    super.key,
    this.controller,
    this.timing = SlideTiming.defaults,
  });

  @override
  State<StatefulWidget> createState() => GreetingsState();
}

class GreetingsState extends State<Greetings> with TickerProviderStateMixin {
  final _random = Random();
  late final _diagonal = RandomCycler(_random, 4);

  Stream<Slide>? _slides;

  @override
  void initState() {
    super.initState();
    reload();

    widget.controller?.addListener(reload);
  }

  @override
  void didUpdateWidget(covariant Greetings oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller?.removeListener(reload);
    widget.controller?.addListener(reload);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(reload);
    super.dispose();
  }

  void reload() {
    setState(
      () => _slides = () async* {
        final slides = await greetings.load(_random);
        while (true) {
          for (final slide in slides) {
            final image = slide.imageSource();
            if (!mounted) {
              break;
            }

            yield Slide(
              key: UniqueKey(),
              image: image,
              text: slide.text,
              vsync: this,
              diagonal: _diagonal.next(),
            );

            await Future.delayed(widget.timing.interval);
          }
        }
      }(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const errorStyle = TextStyle(color: Colors.red);

    return StreamBuilder(
      stream: _slides,
      builder: (context, slide) => AnimatedSwitcher(
        duration: widget.timing.fade,
        switchOutCurve: const Threshold(0.0),
        child: slide.hasError
            ? Text(slide.error!.toString(), style: errorStyle)
            : slide.data,
      ),
    );
  }
}

class SlideTiming {
  static const defaults = SlideTiming(
    interval: Duration(seconds: 10),
    fade: Duration(seconds: 1),
    padding: Duration(milliseconds: 500),
    lineContinuationDelay: Duration(seconds: 1),
    lineBreakDelay: Duration(seconds: 2),
  );

  final Duration interval, fade, padding, lineContinuationDelay, lineBreakDelay;

  Duration get total => interval + fade + padding;
  double normalize(Duration duration) =>
      duration.inMilliseconds / total.inMilliseconds;

  const SlideTiming({
    this.interval = Duration.zero,
    this.fade = Duration.zero,
    this.padding = Duration.zero,
    this.lineContinuationDelay = Duration.zero,
    this.lineBreakDelay = Duration.zero,
  });
}

class Slide extends StatefulWidget {
  final ImageProvider image;
  final String text;
  final SlideTiming timing;
  final TickerProvider vsync;
  final int diagonal;

  const Slide({
    super.key,
    required this.image,
    required this.text,
    this.timing = SlideTiming.defaults,
    required this.vsync,
    required this.diagonal,
  });

  @override
  State<Slide> createState() => _SlideState();
}

class _SlideState extends State<Slide> {
  late final AnimationController animation;
  late Alignment startAlignment, endAlignment;

  void _updateAlignment() {
    startAlignment = Alignment(
      widget.diagonal & 1 == 0 ? -1.0 : 1.0,
      widget.diagonal & 2 == 0 ? -1.0 : 1.0,
    );
    endAlignment = startAlignment * -1;
  }

  @override
  void initState() {
    super.initState();

    animation =
        AnimationController(duration: widget.timing.total, vsync: widget.vsync)
          ..forward();
    _updateAlignment();
  }

  @override
  void didUpdateWidget(covariant Slide oldWidget) {
    super.didUpdateWidget(oldWidget);

    animation
      ..duration = widget.timing.total
      ..resync(widget.vsync);
    _updateAlignment();
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var textDelay = 0.0;
    final textWidgets = <Widget>[];

    for (final line in LineSplitter.split(widget.text)) {
      final textWidget = Text(line);

      textWidgets.add(
        textDelay == 0.0
            ? textWidget
            : FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Interval(
                    textDelay,
                    textDelay + widget.timing.normalize(widget.timing.fade),
                  ),
                ),
                child: textWidget,
              ),
      );

      textDelay += widget.timing.normalize(
        line[line.length - 1] == '.'
            ? widget.timing.lineBreakDelay
            : widget.timing.lineContinuationDelay,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) => Image(
            image: widget.image,
            fit: BoxFit.none,
            alignment:
                Alignment.lerp(startAlignment, endAlignment, animation.value)!,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(100.0),
          child: DefaultTextStyle(
            style: Typography.whiteMountainView.displayLarge!.copyWith(
              fontSize: 32.0,
              color: Colors.white,
              shadows: const [Shadow(offset: Offset(2, 2), blurRadius: 4.0)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: textWidgets,
            ),
          ),
        ),
      ],
    );
  }
}
