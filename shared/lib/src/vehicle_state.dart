import 'model_link.dart';

class VehicleState {
  final ClimateState climate;
  final VolumeState volume;
  final DriveState drive;

  VehicleState([Duration updateShadow = Duration.zero])
      : climate = ClimateState(updateShadow),
        volume = VolumeState(updateShadow),
        drive = DriveState();

  void fromJson(
    Map json,
    UpdateDirection direction, [
    DateTime? now,
  ]) {
    now ??= DateTime.now();

    if (json case {'climate': final Map value}) {
      climate.fromJson(value, direction, now);
    }
    if (json case {'volume': final Map value}) {
      volume.fromJson(value, direction, now);
    }
    if (json case {'drive': final Map value}) {
      drive.fromJson(value);
    }
  }

  Map<String, dynamic> toJson() => {
        'climate': climate.toJson(),
        'volume': volume.toJson(),
        'drive': drive.toJson(),
      };
}

class ClimateState {
  final ModelLink<double> setting;
  ({double? min, double? max}) meta = const (min: null, max: null);
  double? interior;
  double? exterior;

  ClimateState([Duration updateShadow = Duration.zero])
      : setting = ModelLink(updateShadow);

  void fromJson(
    Map json,
    UpdateDirection direction, [
    DateTime? now,
  ]) {
    if (json case {'setting': final value as num?}) {
      setting.update(value?.toDouble(), direction, now);
    }

    if (json case {'meta': final Map value}) {
      meta = (
        min: switch (value) {
          {'min': final value as num?} => value?.toDouble(),
          _ => meta.min,
        },
        max: switch (value) {
          {'max': final value as num?} => value?.toDouble(),
          _ => meta.max,
        },
      );
    }
    if (json case {'interior': final value as num?}) {
      interior = value?.toDouble();
    }
    if (json case {'exterior': final value as num?}) {
      exterior = value?.toDouble();
    }
  }

  Map<String, dynamic> toJson() => {
        'setting': setting.value,
        'meta': {
          'min': meta.min,
          'max': meta.max,
        },
        'interior': interior,
        'exterior': exterior,
      };
}

class VolumeState {
  final ModelLink<double> setting;
  ({double? max, double? step}) meta = const (max: null, step: null);

  VolumeState([Duration updateShadow = Duration.zero])
      : setting = ModelLink(updateShadow);

  void fromJson(
    Map json,
    UpdateDirection direction, [
    DateTime? now,
  ]) {
    if (json case {'setting': final value as num?}) {
      setting.update(value?.toDouble(), direction, now);
    }

    if (json case {'meta': final Map value}) {
      meta = (
        max: switch (value) {
          {'max': final value as num?} => value?.toDouble(),
          _ => meta.max,
        },
        step: switch (value) {
          {'step': final value as num?} => value?.toDouble(),
          _ => meta.step,
        },
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'setting': setting.value,
        'meta': {
          'max': meta.max,
          'step': meta.step,
        },
      };
}

class DriveState {
  String? destination;
  double? milesToArrival;
  double? minutesToArrival;
  double? speed;

  void fromJson(Map json) {
    if (json case {'destination': final value as String?}) {
      destination = value;
    }
    if (json case {'milesToArrival': final value as num?}) {
      milesToArrival = value?.toDouble();
    }
    if (json case {'minutesToArrival': final value as num?}) {
      minutesToArrival = value?.toDouble();
    }
    if (json case {'speed': final value as num?}) {
      speed = value?.toDouble();
    }
  }

  Map<String, dynamic> toJson() => {
        'destination': destination,
        'milesToArrival': milesToArrival,
        'minutesToArrival': minutesToArrival,
        'speed': speed,
      };
}
