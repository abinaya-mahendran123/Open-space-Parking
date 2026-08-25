/// Truncates long labels for compact mobile UI.
String truncateText(String value, int maxLength) {
  final trimmed = value.trim();
  if (trimmed.length <= maxLength) return trimmed;
  final slice = trimmed.substring(0, maxLength);
  final lastSpace = slice.lastIndexOf(' ');
  if (lastSpace > maxLength ~/ 2) {
    return '${slice.substring(0, lastSpace)}…';
  }
  return '$slice…';
}
