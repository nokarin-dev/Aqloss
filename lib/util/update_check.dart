String formatUpdateCheckError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('timed out') || s.contains('timeout')) {
    return 'GitHub timed out. Try again.';
  }
  if (s.contains('failed host lookup') ||
      s.contains('no address associated') ||
      s.contains('network is unreachable') ||
      s.contains('socketexception') ||
      s.contains('connection refused') ||
      s.contains('connection reset')) {
    return 'No network. Check the connection and try again.';
  }
  return 'Could not check for updates.';
}
