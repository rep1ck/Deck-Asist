import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordUtils {
  static String hash(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  static bool verify(String password, String hashed) {
    return hash(password) == hashed;
  }
}
