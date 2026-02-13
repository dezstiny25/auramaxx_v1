import 'dart:async';
import 'package:flutter/material.dart';

class SpeedSlider extends StatelessWidget {
  final double speed;
  final void Function(double) onChanged;

  const SpeedSlider({Key? key, required this.speed, required this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          min: 0,
          max: 100,
          value: speed,
          onChanged: onChanged,
        ),
        Text('${speed.toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 22)),
      ],
    );
  }
}
