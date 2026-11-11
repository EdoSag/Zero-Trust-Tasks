import 'package:zero_trust_tasks/l10n/l10n.dart';
/// Formats a [DateTime] as a short human-readable relative time string,
/// e.g. "just now", "5 minutes ago", "3 hours ago", "2 days ago".
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime.toLocal());

  if (difference.isNegative || difference.inSeconds < 60) {
    return currentL10n.justNow;
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return currentL10n.minutesAgo(minutes);
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return currentL10n.hoursAgo(hours);
  }
  if (difference.inDays < 30) {
    final days = difference.inDays;
    return currentL10n.daysAgo(days);
  }
  if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return currentL10n.monthsAgo(months);
  }
  final years = (difference.inDays / 365).floor();
  return currentL10n.yearsAgo(years);
}
