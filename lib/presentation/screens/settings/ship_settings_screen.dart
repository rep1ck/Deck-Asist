import 'package:flutter/material.dart';
import '../../../core/utils/ship_settings.dart';

class ShipSettingsScreen extends StatefulWidget {
  const ShipSettingsScreen({super.key});

  @override
  State<ShipSettingsScreen> createState() => _ShipSettingsScreenState();
}

class _ShipSettingsScreenState extends State<ShipSettingsScreen> {
  final _ship = TextEditingController();
  final _master = TextEditingController();
  final _company = TextEditingController();
  final _bosun = TextEditingController();
  bool _dual = false;
  bool _maintPhoto = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _ship.text = await ShipSettings.shipName();
    _master.text = await ShipSettings.masterName();
    _company.text = await ShipSettings.companyName();
    _bosun.text = await ShipSettings.bosunName();
    _dual = await ShipSettings.dualSignature();
    _maintPhoto = await ShipSettings.requireMaintPhoto();
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await ShipSettings.save(
      shipName: _ship.text,
      masterName: _master.text,
      companyName: _company.text,
      bosunName: _bosun.text,
      dualSignature: _dual,
      requireMaintPhoto: _maintPhoto,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemi ayarlari kaydedildi')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _ship.dispose();
    _master.dispose();
    _company.dispose();
    _bosun.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Gemi / Rapor Ayarlari')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ship,
            decoration: const InputDecoration(
              labelText: 'Gemi adi (ornek: M/V Zeynep C)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _master,
            decoration: const InputDecoration(
              labelText: 'Master / Suvari adi',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _company,
            decoration: const InputDecoration(
              labelText: 'Sirket (opsiyonel)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bosun,
            decoration: const InputDecoration(
              labelText: 'Reis adi (cift imza icin)',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            title: const Text('Cift imza (Reis + Master)'),
            value: _dual,
            onChanged: (v) => setState(() => _dual = v),
          ),
          SwitchListTile(
            title: const Text('Bakim tamamlamada foto zorunlu'),
            value: _maintPhoto,
            onChanged: (v) => setState(() => _maintPhoto = v),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Kaydet')),
        ],
      ),
    );
  }
}
