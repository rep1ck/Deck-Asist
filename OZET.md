# Deck Asist – Kısa Özet

Bu paket Flutter tabanlı Deck Asist uygulamasının kaynak kodudur.

## Modüller

1. **Kullanıcı & Yetki**
   - Roller: ROOT, MASTER, SECOND, REIS, PERSONEL, INSPECTOR
   - Kullanıcı oluşturma, aktif/pasif ve parola değiştirme

2. **İş Yönetimi + Fotoğraf**
   - İş oluşturma, atama, durum takibi
   - Fotoğraf ekleme ve onay akışı

3. **Stok / Boya**
   - Barkodlu stok kayıtları
   - Giriş / Çıkış / Sayım / Düzeltme
   - Demo boya kayıtları

4. **Planlı Bakım**
   - Periyotlu planlar
   - Sonraki bakım tarihi
   - Bildirim altyapısı

5. **LAN Senkronizasyon Altyapısı**
   - Sunucu URL'si üzerinden veri alma
   - Senkronizasyon kayıtları

6. **Raporlama**
   - Excel
   - PDF

## Android APK

`.github/workflows/build.yml` GitHub Actions üzerinde Android platformunu oluşturur, Drift kodunu üretir, analiz yapar ve release APK üretir.

Çıktı artifact'i: `Deck-Asist-APK`

## Önemli notlar

- Seed boya barkodları `DEMO-xxxx` formatındadır; gerçek ürün barkodu değildir.
- Root hesabı geliştirme/ilk kurulum hesabıdır ve ilk girişten sonra parola değiştirilmelidir.
- Drift generated dosyaları kaynak ZIP'e dahil edilmez; CI tarafından oluşturulur.
