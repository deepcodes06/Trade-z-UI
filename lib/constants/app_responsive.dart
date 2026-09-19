import 'package:flutter/material.dart';

class AppResponsive {
  AppResponsive._();

  static double _screenWidth = 0;
  static double _screenHeight = 0;
  static double _scaleFactor = 1.0;

  static const double designWidth = 390;
  static const double designHeight = 844;

  static void init(BuildContext context) {
    final mq = MediaQuery.of(context);
    _screenWidth = mq.size.width;
    _screenHeight = mq.size.height;
    _scaleFactor = (_screenWidth / designWidth).clamp(0.85, 1.35);
  }

  static double get screenWidth => _screenWidth;
  static double get screenHeight => _screenHeight;
  static double get scaleFactor => _scaleFactor;

  static double w(double v) => v * _scaleFactor;
  static double h(double v) => v * _scaleFactor;

  static double pad(double v) => v * _scaleFactor;

  static double font(double v) => v * _scaleFactor;

  static EdgeInsets padAll(double v) => EdgeInsets.all(w(v));
  static EdgeInsets symH(double v) => EdgeInsets.symmetric(horizontal: w(v));
  static EdgeInsets symV(double v) => EdgeInsets.symmetric(vertical: h(v));

  static bool get isTablet => _screenWidth >= 600;
  static bool get isSmall => _screenWidth < 360;
}
