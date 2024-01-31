import '../timeout.dart';

enum UpdateDirection { fromDownstream, fromUpstream }

class ModelLink<T> {
  T? _value;
  T? get value => _value;

  final Timeout _updateShadow;

  ModelLink([Duration updateShadow = Duration.zero])
      : _updateShadow = Timeout(updateShadow);

  bool canDownlink([DateTime? now]) => _updateShadow.hasElapsed(now);

  void fromDownstream(T? value, [DateTime? now]) {
    _updateShadow.mark(now);
    _value = value;
  }

  bool fromUpstream(T? value, [DateTime? now]) {
    if (canDownlink(now)) {
      _value = value;
      return true;
    } else {
      return false;
    }
  }

  void update(T? value, UpdateDirection direction, [DateTime? now]) =>
      switch (direction) {
        UpdateDirection.fromDownstream => fromDownstream,
        UpdateDirection.fromUpstream => fromUpstream
      }(value, now);
}
