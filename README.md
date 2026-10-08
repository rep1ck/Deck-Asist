# Deck Asist

Güverte yönetim uygulaması — Flutter, offline-first ve LAN senkronizasyonlu.

## Özellikler

- İş yönetimi, atama, durum takibi ve fotoğraf kayıtları
- Stok / boya yönetimi ve barkod okutma
- Planlı bakım ve bildirimler
- Excel / PDF raporlama
- Roller: ROOT, MASTER, SECOND, REIS, PERSONEL, INSPECTOR
- İnternetsiz çalışma
- Aynı Wi-Fi/LAN üzerindeki Deck Asist cihazlarını otomatik keşfetme
- Çift yönlü veri senkronizasyonu
- İlk bağlantıda tam veri birleştirme, sonraki bağlantılarda değişen kayıtların birleştirilmesi
- Güncellenen kayıtlarda `updatedAt` tabanlı last-write-wins yaklaşımı
- İlişkili kayıtlar için cihazlar arasında ID çakışmasını önleyen `syncId`

## LAN senkronizasyonu nasıl çalışır?

Uygulamanın her çalışan örneği iki küçük yerel servis açar:

- UDP `8788`: aynı ağdaki Deck Asist cihazlarını keşfetmek için
- HTTP `8787`: veri senkronizasyonu için

Merkezi bir sunucu veya internet gerekmez. İki veya daha fazla cihaz aynı Wi-Fi/LAN'a bağlandığında uygulamalar birbirini bulur ve uygulama açık olduğu sürece yaklaşık 30 saniyede bir otomatik senkronizasyon dener.

Manuel olarak **LAN Senkronizasyon → Şimdi Senkronize Et** de kullanılabilir.

### Senkronize edilen veriler

- Kullanıcılar
- İşler
- İş atamaları
- İş fotoğraf kayıtları
- Stok ürünleri
- Stok hareketleri
- Bakım planları
- Bakım kayıtları

Senkronizasyon internet üzerinden yapılmaz; cihazlar birbirleriyle yerel ağ üzerinden haberleşir.

> Not: Fotoğraf kaydının veritabanındaki yolu senkronize edilir. Fotoğraf dosyasının kendisinin cihazlar arasında kopyalanması ayrıca dosya aktarımı gerektirir; aynı yerel dosya yolu iki cihazda fiziksel olarak mevcut olmayabilir.

## GitHub'dan APK üretme

Android platform dosyaları repoda tutulmaz. GitHub Actions, sabit Flutter/Java sürümüyle Android projesini oluşturur.

1. ZIP içindeki `deck_master` klasörünün içeriğini bir GitHub reposuna yükleyin.
2. `Actions` sekmesine girin.
3. `Build Deck Asist Android APK` workflow'unu seçin.
4. `Run workflow` ile manuel başlatın veya `main` / `master` dalına push yapın.
5. İşlem tamamlanınca `Deck-Asist-APK` artifact'ından `app-release.apk` dosyasını indirin.

Workflow:

- Flutter 3.24.5 + Java 17
- Android platform oluşturma
- LAN için Android INTERNET izni
- `flutter pub get`
- Drift kod üretimi
- `flutter analyze`
- `flutter build apk --release`
- Release APK artifact yükleme

## Yerelde çalıştırma

```bash
flutter create . --project-name deck_asist --platforms=android
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter build apk --release
```

APK:
`build/app/outputs/flutter-apk/app-release.apk`

## Demo boya barkodları

Seed edilen boya kayıtlarındaki `DEMO-xxxx` kodları gerçek Akzo Nobel barkodları değildir. Gerçek ürün/barkod listesi doğrulandıktan sonra değiştirilmelidir.

## Root hesabı

İlk veritabanı oluşturulduğunda örnek yönetici hesabı otomatik oluşturulur:

- Kullanıcı: `root@zeynepc.arkas`
- Şifre: `******` mail ile ulaşın brlylmz77@gmailom

Üretim kullanımında ilk girişten sonra bu parolanın değiştirilmesi gerekir.

## Proje yapısı

```text
lib/
  core/
  data/database/
  presentation/screens/
  services/
assets/
.github/workflows/
```

Drift'in `app_database.g.dart` gibi üretilen dosyaları repoya eklenmez; CI bunları `build_runner` ile üretir.
