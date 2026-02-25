/// Validate IPv4 address format (e.g. "192.168.1.100")
bool isValidIpv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  for (final part in parts) {
    final num = int.tryParse(part);
    if (num == null || num < 0 || num > 255) return false;
  }
  return true;
}
