import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/util/ui/relative_time.dart';

void main() {
  setUpAll(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  test('relativeAgo buckets by minute, hour and day', () {
    final now = DateTime(2026, 10, 29, 12, 0);
    expect(relativeAgo(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
    expect(relativeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
    expect(relativeAgo(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
    expect(relativeAgo(now.subtract(const Duration(days: 2)), now: now), '2 d ago');
  });
}
