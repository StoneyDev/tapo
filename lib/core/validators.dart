/// Validate IPv4 address format (e.g. "192.168.1.100")
bool isValidIpv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  // Digits only, no leading zero: "010" reads as octal in some resolvers.
  final octet = RegExp(r'^(0|[1-9]\d{0,2})$');
  return parts.every((part) => octet.hasMatch(part) && int.parse(part) <= 255);
}
