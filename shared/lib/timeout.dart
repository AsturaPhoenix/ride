class Timeout {
  final Duration duration;
  DateTime? _start;

  Timeout([this.duration = Duration.zero]);

  void mark([DateTime? now]) => _start = now ?? DateTime.now();

  bool hasElapsed([DateTime? now]) =>
      _start == null || (now ?? DateTime.now()).difference(_start!) > duration;
}
