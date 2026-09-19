import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Full-screen backdrop of soft ambient neon light blobs.
///
/// Solid colour circles are individually softened with a heavy
/// [ImageFilter.blur] (through [ImageFiltered]) so they become ambient pools
/// of light — no gradients are used. The widget is non-interactive and paints
/// behind the app content, where it is picked up and softened again by the
/// glass cards' [BackdropFilter].
class NeonBackdrop extends StatelessWidget {
  final double sigma;

  const NeonBackdrop({super.key, this.sigma = 90});

  /// Neon palette used by the backdrop.
  static const Color blue = Color(0xFF1743A3);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFF472B6);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Blob(
              color: blue,
              sigma: sigma,
              diameterFraction: 0.78,
              alignment: const Alignment(-1.35, -1.45),
              opacity: 0.9,
            ),
            _Blob(
              color: cyan,
              sigma: sigma,
              diameterFraction: 0.50,
              alignment: const Alignment(1.25, -1.35),
              opacity: 0.7,
            ),
            _Blob(
              color: purple,
              sigma: sigma,
              diameterFraction: 0.66,
              alignment: const Alignment(-1.40, 1.40),
              opacity: 0.8,
            ),
            _Blob(
              color: pink,
              sigma: sigma,
              diameterFraction: 0.52,
              alignment: const Alignment(1.30, 1.25),
              opacity: 0.7,
            ),
            _Blob(
              color: cyan,
              sigma: sigma * 1.5,
              diameterFraction: 0.55,
              alignment: Alignment.center,
              opacity: 0.28,
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double sigma;
  final double diameterFraction;
  final Alignment alignment;
  final double opacity;

  const _Blob({
    required this.color,
    required this.sigma,
    required this.diameterFraction,
    required this.alignment,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).longestSide * diameterFraction / 2),
      child: Align(
        alignment: alignment,
        child: AspectRatio(
          aspectRatio: 1,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: opacity),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
