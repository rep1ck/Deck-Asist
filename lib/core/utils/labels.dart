/// Türkçe etiketler – durum, öncelik, stok hareketi
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
      case 'RASPA':
        return 'Raspa';
      case 'KABIN':
        return 'Kabin';
      case 'DIGER':
        return 'Diğer';
      default:
        return c;
    }
  }
}
