# ODT Altyazıcı

ODT Altyazıcı, macOS üzerinde video ve ses dosyalarından Türkçe altyazı üretmek için hazırlanmış sade bir masaüstü uygulamasıdır.

Uygulama terminal kullanmadan çalışır. Kullanıcı videoyu seçer veya sürükler, `.srt` ve/veya `.txt` çıktısını seçer, ardından **Altyazı Oluştur** butonuna basar.

## Özellikler

- Native macOS arayüzü
- Sürükle-bırak dosya seçimi
- Türkçe transkripsiyon
- Sabit model: `large-v3-turbo`
- Çıktılar: `.srt` ve `.txt`
- Çıktıları videonun bulunduğu klasöre kaydetme
- İşlem bitince bildirim
- Sonuç klasörünü Finder'da açma

Kullanım:

1. DMG dosyasını açın.
2. `ODT Altyazıcı.app` uygulamasını `Applications` klasörüne sürükleyin.
3. Uygulamayı açın.
4. Video veya ses dosyasını sürükleyin ya da seçin.
5. `.srt` ve/veya `.txt` çıktısını seçin.
6. **Altyazı Oluştur** butonuna basın.

Not: Bu sürüm Apple Silicon Mac'ler içindir. M1, M2, M3 ve M4 cihazlarda kullanılmak üzere hazırlanmıştır.

## Üçüncü Taraf Bileşenler

Bu uygulama aşağıdaki açık kaynak bileşenlerle çalışır:

- `whisper.cpp`: MIT License
- `ggml-large-v3-turbo.bin`: whisper.cpp GGML model dosyası
- `ffmpeg`: Build seçeneklerine göre LGPL/GPL lisans koşulları geçerli olabilir
- `imageio-ffmpeg`: BSD-2-Clause License, bağımsız ffmpeg binary dağıtımı için kullanılmıştır

## Proje Durumu

Bu proje ilk çalışan prototip aşamasındadır. Ekip içi kullanım için hazırlanmıştır.

Henüz yapılabilecek iyileştirmeler:

- Apple Developer hesabıyla imzalama ve notarization
- Intel Mac için ayrı paket
- Daha gelişmiş hata raporlama
- DMG arka planı ve görsel düzenleme
