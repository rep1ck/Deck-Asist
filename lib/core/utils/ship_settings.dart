import 'package:shared_preferences/shared_preferences.dart';

class ShipSettings {
  static const _kShip = 'ship_name';
  static const _kMaster = 'master_name';
  static const _kCompany = 'company_name';
  static const _kBosun = 'bosun_name';
  static const _kDualSign = 'dual_signature';
  static const _kMaintPhoto = 'require_maint_photo';

  static Future<String> shipName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kShip) ?? 'M/V Zeynep C';
  }

  static Future<String> masterName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kMaster) ?? 'Master';
  }

  static Future<String> companyName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kCompany) ?? '';
  }

  static Future<String> bosunName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kBosun) ?? '';
  }

  static Future<bool> dualSignature() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kDualSign) ?? false;
  }

  static Future<bool> requireMaintPhoto() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kMaintPhoto) ?? false;
  }

  static Future<void> save({
    required String shipName,
    required String masterName,
    String companyName = '',
    String bosunName = '',
    bool dualSignature = false,
    bool requireMaintPhoto = false,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _kShip, shipName.trim().isEmpty ? 'M/V Zeynep C' : shipName.trim());
    await p.setString(_kMaster, masterName.trim());
    await p.setString(_kCompany, companyName.trim());
    await p.setString(_kBosun, bosunName.trim());
    await p.setBool(_kDualSign, dualSignature);
    await p.setBool(_kMaintPhoto, requireMaintPhoto);
  }

  static Future<String> signatureBlock() async {
    final ship = await shipName();
    final master = await masterName();
    final dual = await dualSignature();
    final bosun = await bosunName();
    if (dual && bosun.isNotEmpty) {
      return '$ship\nReis: $bosun\nMaster: $master';
    }
    return '$ship Master\n$master';
  }

  static Future<String> nextReportNo() async {
    final ship = await shipName();
    final code = ship.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final short = code.length > 6 ? code.substring(0, 6) : code;
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return '$short-GUV-$stamp';
  }
}
