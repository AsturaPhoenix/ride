import 'dart:async';

import 'package:flutter/material.dart';

class NumericControl extends StatelessWidget {
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  final double? value;
  final double min, max, step;
  final void Function(double value)? onChange;
  final Widget child;

  const NumericControl({
    super.key,
    this.mainAxisSize = MainAxisSize.min,
    this.mainAxisAlignment = MainAxisAlignment.spaceEvenly,
    this.value,
    this.min = double.negativeInfinity,
    this.max = double.infinity,
    this.step = 1.0,
    this.onChange,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: mainAxisSize,
        mainAxisAlignment: mainAxisAlignment,
        children: [
          ControlButton(
            icon: const Icon(Icons.chevron_left),
            action: onChange == null || value == null || value! <= min
                ? null
                : () {
                    final raw = value! - step;
                    onChange!(raw - min < step ? min : raw);
                  },
          ),
          child,
          ControlButton(
            icon: const Icon(Icons.chevron_right),
            action: onChange == null || value == null || value! >= max
                ? null
                : () {
                    final raw = value! + step;
                    onChange!(max - raw < step ? max : raw);
                  },
          ),
        ],
      );
}

class ControlButton extends StatefulWidget {
  final Widget icon;
  final void Function()? action;

  const ControlButton({super.key, required this.icon, this.action});

  @override
  State<StatefulWidget> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  static const longPressActionFrequency = Duration(milliseconds: 75);
  Timer? _repeat;

  @override
  void didUpdateWidget(covariant ControlButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.action == null) {
      _repeat?.cancel();
      _repeat = null;
    }
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onLongPressStart: widget.action == null
            ? null
            : (_) {
                widget.action!();
                _repeat = Timer.periodic(
                  longPressActionFrequency,
                  (timer) => widget.action!(),
                );
              },
        onLongPressEnd: (_) {
          _repeat?.cancel();
          _repeat = null;
        },
        child: IconButton(
          icon: widget.icon,
          onPressed: widget.action,
        ),
      );
}
