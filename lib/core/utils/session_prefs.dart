import 'package:shared_preferences/shared_preferences.dart';

/// Beni hatirla — kullanici adi + sifre yerel saklama (LAN / offline cihaz)
class SessionPrefs {
  static const _kRemember = 'remember_me';
  static const _kUser = 'remember_username';
  static const _kPass = 'remember_password';

  static Future<bool> getRememberMe() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kRemember) ?? false;
  }

  static Future<({String username, String password})?> loadCredentials() async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_kRemember) ?? false)) return null;
    final u = p.getString(_kUser);
    final pw = p.getString(_kPass);
    if (u == null || u.isEmpty || pw == null) return null;
    return (username: u, password: pw);
  }

  static Future<void> saveCredentials({
    required bool remember,
    required String username,
    required String password,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRemember, remember);
    if (remember) {
      await p.setString(_kUser, username);
      await p.setString(_kPass, password);
    } else {
      await p.remove(_kUser);
      await p.remove(_kPass);
    }
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRemember, false);
    await p.remove(_kUser);
    await p.remove(_kPass);
  }
}
