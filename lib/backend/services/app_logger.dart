import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void market(String message) {
    debugPrint('[Market] $message');
  }

  static void ui(String message) {
    debugPrint('[UI] $message');
  }

  static void navigation(String message) {
    debugPrint('[Nav] $message');
  }

  static String formatSnapshot(String source, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return 'source=$source count=0';
    }

    final sample = items.take(5).map((item) {
      final symbol = item['symbol']?.toString() ?? 'n/a';
      final ltp = item['ltp'];
      final formattedLtp = ltp is num ? ltp.toStringAsFixed(2) : 'n/a';
      return '$symbol:$formattedLtp';
    }).join(', ');

    return 'source=$source count=${items.length} sample=[$sample]';
  }
}
