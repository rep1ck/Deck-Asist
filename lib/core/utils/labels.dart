/// Türkçe etiketler – durum, öncelik, stok, kategori, birim
class Labels {
  static String jobStatus(String status) {
    switch (status) {
      case 'PENDING':
        return 'Beklemede';
      case 'IN_PROGRESS':
        return 'Devam Ediyor';
      case 'COMPLETED':
        return 'Tamamlandı';
      case 'APPROVED':
        return 'Onaylandı';
      case 'CANCELLED':
        return 'İptal';
      default:
        return status;
    }
  }

  static String priority(String p) {
    switch (p) {
      case 'LOW':
        return 'Düşük';
      case 'NORMAL':
        return 'Normal';
      case 'HIGH':
        return 'Yüksek';
      case 'URGENT':
        return 'Acil';
      default:
        return p;
    }
  }

  static String movementType(String t) {
    switch (t) {
      case 'GIRIS':
        return 'Giriş (Stok Ekle)';
      case 'CIKIS':
        return 'Çıkış (Kullanım)';
      case 'SAYIM':
        return 'Sayım';
      case 'DUZELTME':
        return 'Düzeltme';
      default:
        return t;
    }
  }

  static String role(String r) {
    switch (r) {
      case 'ROOT':
        return 'Sistem Yöneticisi';
      case 'MASTER':
        return 'Master (Kaptan)';
      case 'SECOND':
        return '2. Kaptan';
      case 'REIS':
        return 'Güverte Reisi';
      case 'PERSONEL':
        return 'Güverte Personeli';
      case 'INSPECTOR':
        return 'Şirket / Enspektör';
      default:
        return r;
    }
  }

  static String category(String c) {
    switch (c) {
      case 'BOYA':
        return 'Boya';
      case 'KUMANYA':
        return 'Kumanya';
      case 'KABIN':
        return 'Kabin Malzemeleri';
      case 'RASPA':
        return 'Raspa / Boya Yardımcı';
      case 'EL_ALETI':
        return 'Elektrikli / El Aleti';
      case 'KKD':
        return 'KKD (Gözlük, Eldiven vb.)';
      case 'DIGER':
        return 'Diğer';
      default:
        return c;
    }
  }

  static const categoryValues = [
    'BOYA',
    'KUMANYA',
    'KABIN',
    'RASPA',
    'EL_ALETI',
    'KKD',
    'DIGER',
  ];

  static const unitValues = ['Lt', 'Kg', 'Adet', 'Kutu', 'Paket', 'Metre', 'Çift'];

  static String unit(String u) {
    switch (u) {
      case 'Lt':
        return 'Lt (Litre)';
      case 'Kg':
        return 'Kg';
      case 'Adet':
        return 'Adet';
      case 'Kutu':
        return 'Kutu';
      case 'Paket':
        return 'Paket';
      case 'Metre':
        return 'Metre';
      case 'Çift':
        return 'Çift';
      default:
        return u;
    }
  }
}
