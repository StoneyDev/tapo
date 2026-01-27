import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// SHA1 hash of a string, returns hex string
String sha1Hash(String input) {
  final bytes = utf8.encode(input);
  final digest = sha1.convert(bytes);
  return digest.toString();
}

/// SHA1 hash of a string, returns raw bytes
Uint8List sha1HashBytes(String input) {
  final bytes = utf8.encode(input);
  final digest = sha1.convert(bytes);
  return Uint8List.fromList(digest.bytes);
}

/// SHA256 hash of bytes, returns raw bytes
Uint8List sha256HashBytes(List<int> input) {
  final digest = sha256.convert(input);
  return Uint8List.fromList(digest.bytes);
}

/// SHA256 hash of bytes, returns hex string
String sha256Hash(List<int> input) {
  final digest = sha256.convert(input);
  return digest.toString();
}

/// Generate KLAP auth hash: SHA256(SHA1(email) + SHA1(password))
Uint8List generateAuthHash(String email, String password) {
  final emailSha1 = sha1HashBytes(email);
  final passwordSha1 = sha1HashBytes(password);
  final combined = Uint8List.fromList([...emailSha1, ...passwordSha1]);
  return sha256HashBytes(combined);
}

/// AES-128-CBC encrypt with PKCS7 padding
Uint8List aesEncrypt(Uint8List data, Uint8List key, Uint8List iv) {
  final cipher = CBCBlockCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(key), iv));

  // PKCS7 padding
  final blockSize = cipher.blockSize;
  final padLength = blockSize - (data.length % blockSize);
  final padded = Uint8List(data.length + padLength);
  padded.setAll(0, data);
  for (var i = data.length; i < padded.length; i++) {
    padded[i] = padLength;
  }

  final output = Uint8List(padded.length);
  var offset = 0;
  while (offset < padded.length) {
    offset += cipher.processBlock(padded, offset, output, offset);
  }
  return output;
}

/// AES-128-CBC decrypt with PKCS7 unpadding
Uint8List aesDecrypt(Uint8List data, Uint8List key, Uint8List iv) {
  final cipher = CBCBlockCipher(AESEngine())
    ..init(false, ParametersWithIV(KeyParameter(key), iv));

  final output = Uint8List(data.length);
  var offset = 0;
  while (offset < data.length) {
    offset += cipher.processBlock(data, offset, output, offset);
  }

  // Remove PKCS7 padding
  final padLength = output.last;
  if (padLength > 0 && padLength <= 16) {
    return Uint8List.sublistView(output, 0, output.length - padLength);
  }
  return output;
}
