import 'package:flutter/material.dart';
import '../control_page.dart'; // import for ActiveOverlay enum

class OverlayCard extends StatelessWidget {
  final Animation<double> overlayScale;
  final Animation<double> overlayFade;
  final ActiveOverlay activeOverlay;
  final Widget modeOverlay;
  final Widget speedOverlay;
  final Widget presetOverlay;

  const OverlayCard({
    Key? key,
    required this.overlayScale,
    required this.overlayFade,
    required this.activeOverlay,
    required this.modeOverlay,
    required this.speedOverlay,
    required this.presetOverlay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget child;
    double height;

    switch (activeOverlay) {
      case ActiveOverlay.mode:
        child = modeOverlay;
        height = 260;
        break;
      case ActiveOverlay.speed:
        child = speedOverlay;
        height = 180;
        break;
      case ActiveOverlay.presets:
        child = presetOverlay;
        height = 320;
        break;
      default:
        child = const SizedBox();
        height = 0;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final safePadding = MediaQuery.of(context).padding.top +
        MediaQuery.of(context).padding.bottom +
        40.0;
    final maxAllowed = (screenHeight - safePadding) * 0.85;
    final containerHeight = (height.clamp(0.0, maxAllowed) as double);

    return ScaleTransition(
      scale: overlayScale,
      child: FadeTransition(
        opacity: overlayFade,
        child: Container(
          width: 320,
          height: containerHeight,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: child,
        ),
      ),
    );
  }
}
