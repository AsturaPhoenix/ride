import 'package:clock/clock.dart';

class Timeout {
  final Duration duration;
  DateTime? _start;

  Timeout([this.duration = Duration.zero]);

  void mark([DateTime? now]) => _start = now ?? clock.now();

  bool hasElapsed([DateTime? now]) =>
      _start == null || (now ?? clock.now()).difference(_start!) >= duration;
}
