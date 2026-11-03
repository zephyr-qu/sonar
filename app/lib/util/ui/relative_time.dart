import 'package:sonar/gen/strings.g.dart';

/// Human readable "5 分钟前" for a past [time], used for devices that are not
/// currently reachable. [now] exists for tests.
String relativeAgo(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) {
    return t.nearbyTab.justNow;
  }
  if (diff.inHours < 1) {
    return t.nearbyTab.minutesAgo(n: diff.inMinutes);
  }
  if (diff.inDays < 1) {
    return t.nearbyTab.hoursAgo(n: diff.inHours);
  }
  return t.nearbyTab.daysAgo(n: diff.inDays);
}
