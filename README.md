# Deck Asist

Güverte yönetim uygulaması — Flutter, Android APK odaklı, offline-first.

## Modüller

- İş yönetimi, atama, durum takibi ve fotoğraf
- Stok / boya yönetimi ve barkod okutma
- Planlı bakım ve bildirimler
- Excel / PDF raporlama
- Roller: ROOT, MASTER, SECOND, REIS, PERSONEL, INSPECTOR
- LAN senkronizasyon altyapısı

## GitHub'dan APK üretme

Bu depoda Android platform dosyaları kaynak olarak tutulmaz. GitHub Actions, her çalışmada aynı Flutter sürümüyle Android projesini oluşturur.

1. Bu klasörün içeriğini bir GitHub reposuna yükleyin.
2. `Actions` sekmesine girin.
3. `Build Deck Asist Android APK` workflow'unu seçin.
4. `Run workflow` ile manuel başlatabilir veya `main` / `master` dalına push yapabilirsiniz.
5. İşlem tamamlanınca `Deck-Asist-APK` artifact'ından `app-release.apk` dosyasını alın.

Workflow şu sırayla çalışır:

- Flutter 3.24.5 + Java 17
- Android platform oluşturma
- `flutter pub get`
- Drift kod üretimi
- `flutter analyze`
- `flutter build apk --release`

## Yerelde çalıştırma

Flutter 3.24.5 kullanılması önerilir:

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

Seed edilen boya kayıtlarındaki `DEMO-xxxx` kodları gerçek Akzo Nobel barkodları değildir. Gerçek ürün/barkod listesi doğrulandıktan sonra değiştirilmelidir. Böylece uygulama yanlış bir barkodu gerçek ürün barkoduymuş gibi kabul etmez.

## Root hesabı

İlk veritabanı oluşturulduğunda örnek yönetici hesabı otomatik oluşturulur:

- Kullanıcı: `root@zeynepc.arkas`
- Şifre: `zeynepcroot`

**Üretim kullanımında ilk girişten sonra bu parolanın değiştirilmesi gerekir.** Kimlik bilgilerini GitHub'a koyulan dokümantasyonda gerçek üretim parolası olarak kullanmayın.

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
