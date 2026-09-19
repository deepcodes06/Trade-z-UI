/// NSE market-hours helper (IST = UTC+5:30, no DST).
///
/// Mirrors the backend's `src/utils/market-hours.js` so the app stops live
/// polling when the market is closed and shows the settled last price.
///   - Weekdays Mon-Fri
///   - Trading window 09:15 - 15:30 IST
class MarketHours {
  MarketHours._();

  static const Duration _istOffset = Duration(hours: 5, minutes: 30);
  static const int _openMinutes = 9 * 60 + 15; // 09:15
  static const int _closeMinutes = 15 * 60 + 30; // 15:30

  static bool isOpen([DateTime? now]) {
    final ist = (now ?? DateTime.now()).toUtc().add(_istOffset);
    final dow = ist.weekday; // 1=Mon .. 7=Sun
    if (dow == DateTime.saturday || dow == DateTime.sunday) return false;
    final minutes = ist.hour * 60 + ist.minute;
    return minutes >= _openMinutes && minutes < _closeMinutes;
  }

  static String istLabel([DateTime? now]) {
    final ist = (now ?? DateTime.now()).toUtc().add(_istOffset);
    final hh = ist.hour.toString().padLeft(2, '0');
    final mm = ist.minute.toString().padLeft(2, '0');
    return '$hh:$mm IST';
  }
}