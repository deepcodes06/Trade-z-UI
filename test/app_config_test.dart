import 'package:flutter_test/flutter_test.dart';
import 'package:trade_z/constants/app_config.dart';

void main() {
  test('apiPrefix is mounted under /api', () {
    expect(AppConfig.apiPrefix, '/api');
  });
}