import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ParallelogramBorder extends OutlinedBorder {
  final double skew;

  const ParallelogramBorder({
    super.side,
    this.skew = 0.0,
  });

  @override
  ParallelogramBorder scale(double t) => ParallelogramBorder(
        side: side.scale(t),
        skew: skew,
      );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is ParallelogramBorder) {
      return ParallelogramBorder(
        side: BorderSide.lerp(a.side, side, t),
        skew: ui.lerpDouble(a.skew, skew, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is ParallelogramBorder) {
      return ParallelogramBorder(
        side: BorderSide.lerp(side, b.side, t),
        skew: ui.lerpDouble(skew, b.skew, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  /// Returns a copy of this LinearBorder with the given fields replaced with
  /// the new values.
  @override
  ParallelogramBorder copyWith({
    BorderSide? side,
    double? skew,
  }) =>
      ParallelogramBorder(
        side: side ?? this.side,
        skew: skew ?? this.skew,
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final Rect adjustedRect =
        dimensions.resolve(textDirection).deflateRect(rect);
    return getOuterPath(adjustedRect);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final offset = skew * rect.height;

    return Path()
      ..addPolygon(
        [
          if (offset >= 0) rect.topLeft else rect.topLeft.translate(-offset, 0),
          if (offset < 0)
            rect.topRight
          else
            rect.topRight.translate(-offset, 0),
          if (offset >= 0)
            rect.bottomRight
          else
            rect.bottomRight.translate(-offset, 0),
          if (offset < 0)
            rect.bottomLeft
          else
            rect.bottomLeft.translate(offset, 0),
        ],
        true,
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    // TODO(AsturaPhoenix): We don't need this yet.
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ParallelogramBorder &&
        other.side == side &&
        other.skew == skew;
  }

  @override
  int get hashCode => Object.hash(side, skew);

  @override
  String toString() => 'ParallelogramBorder(side: $side, skew: $skew)';
}
