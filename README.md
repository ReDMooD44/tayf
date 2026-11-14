# TAYF

Işık huzmelerini prizmalar, aynalar ve merceklerle hedefe taşıdığınız küçük bir
bulmaca oyunu. Aynı oyunun üç sürümü bu depoda durur:

| Klasör | Ne | Nasıl çalışır |
|---|---|---|
| `index.html` | Web sürümü (tek dosya) | Tarayıcıda açılır, kurulum gerekmez |
| `tayf_flutter/` | **Flutter sürümü** | Android/iOS uygulaması; asıl mobil sürüm budur |
| `android/` | WebView sarmalayıcısı | `index.html`'i Android'de gösteren ince kabuk |

Mobil sürüm Flutter ile yazıldı: çizim `CustomPainter`, ses cihazda sentezleniyor,
ilerleme `shared_preferences` ile yerelde tutuluyor.

## Android APK

Gerekenler: Flutter 3.50+, JDK 17, Android SDK (build-tools 36 ve platform 36).

```bash
cd tayf_flutter
flutter pub get
flutter build apk --release
# çıktı: build/app/outputs/flutter-apk/app-release.apk
```

ABI başına daha küçük APK'lar için:

```bash
flutter build apk --release --split-per-abi
```

### İmzalama

Release anahtarı depoda tutulmaz. `android/key.properties` varsa Gradle onu
kullanır; yoksa derleme debug anahtarıyla yapılır (yalnızca test için).

```properties
# tayf_flutter/android/key.properties  (gitignore'da)
storePassword=...
keyPassword=...
keyAlias=tayf
storeFile=../../../release/tayf-release.jks
```

Bu makinede anahtar `release/tayf-release.jks` olarak üretildi; parolası ve
yedekleme notları `release/KEYSTORE-README.txt` içinde. **O iki dosyayı
kaybetmeyin**: Android'de bir uygulama yalnızca onu ilk imzalayan anahtarla
güncellenebilir.

GitHub Actions da aynı anahtarla imzalayabilir. Depo ayarlarında
**Settings → Secrets and variables → Actions** altına dört sır ekleyin:

| Sır | Değer |
|---|---|
| `KEYSTORE_BASE64` | `base64 -w0 release/tayf-release.jks` çıktısı (Windows: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("release\tayf-release.jks"))`) |
| `KEYSTORE_PASSWORD` | `KEYSTORE-README.txt` içindeki parola |
| `KEY_ALIAS` | `tayf` |
| `KEY_PASSWORD` | anahtar parolası (aynı) |

Sırlar tanımlıysa `v*` etiketinde derlenen APK imzalanıp Release'e eklenir.
Tanımlı değilse iş akışı yalnızca "Artifacts" altına debug imzalı bir APK
bırakır ve Release oluşturmaz — o APK'yı dağıtmayın.

## Android'e uyarlananlar

- `minSdk 24` (Android 7.0+), `targetSdk` Flutter'ın güncel değeri
- Portre kilidi, immersive (tam ekran) mod, çentik için `SafeArea`
- Dokunmatik: sürükle-bırak, parmakla döndürme, 0,1° ince ayar paneli
- Geri tuşu: açık sayfayı kapatır, oyun içindeyse menüyü açar; menüdeyken çıkar
- Uygulama arka plana geçince süre/can işlemez
- Parça seçiminde ve bölüm çözümünde hafif dokunsal geri bildirim
- 512 px mağaza ikonu, adaptive icon ve yuvarlak ikon

## F-Droid

Depo F-Droid'in istediği biçimde hazırlanmıştır:

- `LICENSE` — **GNU GPL v3.0** (F-Droid yalnızca özgür lisanslı uygulamaları alır)
- `fastlane/metadata/android/{en-US,tr-TR}/` — başlık, kısa/uzun açıklama
- `fastlane/metadata/android/en-US/images/` — 512×512 ikon ve telefon ekran görüntüleri
- `fdroid/com.tayf.tayf.yml` — fdroiddata için örnek derleme tarifi
- Ağ izni yok, reklam yok, analitik yok, kapalı kaynak SDK yok

Yayın akışı:

1. Depoyu GitHub'da **herkese açık** olarak yayınlayın.
2. `pubspec.yaml` sürümünü artırın (`version: 1.0.1+2` gibi) ve `v1.0.1` etiketi
   (tag) oluşturup Release yayınlayın.
3. İlk başvuru için F-Droid'in
   [RFP (Requests for Packaging)](https://gitlab.com/fdroid/rfp/-/issues) sayfasında
   yeni bir issue açın. Depo adresi, lisans ve "Flutter" bilgisini yazın.
   Gönüllüler derleme tarifini kendileri hazırlar.
4. İsterseniz `fdroid/com.tayf.tayf.yml` dosyasını
   [fdroiddata](https://gitlab.com/fdroid/fdroiddata) deposuna ekleyip merge
   request açabilirsiniz. Tarifteki `SourceCode`/`Repo` adresini kendi deponuzla
   değiştirmeyi unutmayın.

F-Droid kendi APK'sını kendi anahtarıyla imzalar; sizin keystore'unuz yalnızca
GitHub Releases'e ekleyeceğiniz APK'lar içindir.

## Testler

```bash
cd tayf_flutter
flutter analyze
flutter test
```

## Lisans

GNU GPL v3.0 — bkz. `LICENSE`. Oyun kodu ve üretilen görseller bu lisans
altındadır.
