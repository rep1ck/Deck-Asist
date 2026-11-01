class Labels {
  static String jobStatus(String status) {
    switch (status) {
      case 'PENDING':
        return 'Beklemede';
      case 'IN_PROGRESS':
        return 'Devam Ediyor';
      case 'COMPLETED':
        return 'Tamamlandi';
      case 'APPROVED':
        return 'Onaylandi';
      case 'CANCELLED':
        return 'Iptal';
      default:
        return status;
    }
  }

  static String priority(String p) {
    switch (p) {
      case 'LOW':
        return 'Dusuk';
      case 'NORMAL':
        return 'Normal';
      case 'HIGH':
        return 'Yuksek';
      case 'URGENT':
        return 'Acil';
      default:
        return p;
    }
  }

  static String movementType(String t) {
    switch (t) {
      case 'GIRIS':
        return 'Giris (Stok Ekle)';
      case 'CIKIS':
        return 'Cikis (Kullanim)';
      case 'SAYIM':
        return 'Sayim';
      case 'DUZELTME':
        return 'Duzeltme';
      default:
        return t;
    }
  }

  static String role(String r) {
    switch (r) {
      case 'ROOT':
        return 'Sistem Yoneticisi';
      case 'MASTER':
        return 'Master (Kaptan)';
      case 'SECOND':
        return '2. Kaptan';
      case 'REIS':
        return 'Guverte Reisi';
      case 'PERSONEL':
        return 'Guverte Personeli';
      case 'INSPECTOR':
        return 'Sirket / Enspektor';
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
        return 'Raspa / Boya Yardimci';
      case 'EL_ALETI':
        return 'Elektrikli / El Aleti';
      case 'KKD':
        return 'KKD (Gozluk, Eldiven vb.)';
      case 'DIGER':
        return 'Diger';
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

  static const unitValues = ['Lt', 'Kg', 'Adet', 'Kutu', 'Paket', 'Metre', 'Cift'];

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
      case 'Cift':
        return 'Cift';
      default:
        return u;
    }
  }

  static String jobCategory(String c) {
    switch (c) {
      case 'BOYA':
        return 'Boya';
      case 'RASPA':
        return 'Raspa';
      case 'MERDIVEN':
        return 'Merdiven / Iskele';
      case 'EMINIYET':
        return 'Emniyet';
      case 'GENEL':
        return 'Genel';
      default:
        return c;
    }
  }
}
