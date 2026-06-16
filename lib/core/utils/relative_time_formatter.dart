/// Formats a [DateTime] as a short human-readable relative time string,
/// e.g. "just now", "5 minutes ago", "3 hours ago", "2 days ago".
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime.toLocal());

  if (difference.isNegative || difference.inSeconds < 60) {
    return 'just now';
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return '$minutes minute${minutes == 1 ? '' : 's'} ago';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return '$hours hour${hours == 1 ? '' : 's'} ago';
  }
  if (difference.inDays < 30) {
    final days = difference.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }
  if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return '$months month${months == 1 ? '' : 's'} ago';
  }
  final years = (difference.inDays / 365).floor();
  return '$years year${years == 1 ? '' : 's'} ago';
}
