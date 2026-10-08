DECK ASIST - HAZIR LAN/SYNC DUZELTMESI

Python GEREKMEZ.

1) Bu klasoru ZIP'ten cikarin.
2) apply_fix.bat dosyasina cift tiklayin.
3) Repo yolu sorarsa masaustundeki Deck-Asist klasorunu secin.
   Ornek: C:\Users\Birol\Desktop\Deck-Asist
4) Islem bittiginde GitHub Desktop'u acin.
5) Degisiklikleri kontrol edin.
6) Commit yapin ve Push yapin.

Yapilan ana duzeltmeler:
- LAN /sync isteklerine HMAC tabanli kimlik dogrulama.
- Replay isteklerine karsi nonce/timestamp kontrolu.
- Buyuk fotograflar icin SHA-256 hash + dogrudan LAN dosya aktarimi.
- Cihazlar arasinda yerel foto dosya yollarinin tasinmamasi.
- Stokta currentStock yerine stockMovements kaynak gercek olarak kullanilir.
- Stok hareketleri tarih + olusturma zamani + syncId ile deterministik hesaplanir.
- CI'da flutter analyze hatalarinin gizlenmesi kaldirildi.

NOT: Patch sonrasi `flutter pub get` ve `flutter analyze` calistirin.
