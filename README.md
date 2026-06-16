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

## Kullanıcı İçin

Dağıtım için önerilen dosya:

```text
ODT Altyazıcı.dmg
```

Kullanım:

1. DMG dosyasını açın.
2. `ODT Altyazıcı.app` uygulamasını `Applications` klasörüne sürükleyin.
3. Uygulamayı açın.
4. Video veya ses dosyasını sürükleyin ya da seçin.
5. `.srt` ve/veya `.txt` çıktısını seçin.
6. **Altyazı Oluştur** butonuna basın.

Not: Bu sürüm Apple Silicon Mac'ler içindir. M1, M2, M3 ve M4 cihazlarda kullanılmak üzere hazırlanmıştır.

## Geliştirme

Geliştirme sırasında uygulamayı çalıştırmak için:

```bash
swift run
```

Uygulama paketi oluşturmak için:

```bash
./scripts/package_app.sh
```

Paket şurada oluşur:

```text
dist/ODT Altyazıcı.app
```

DMG paketi oluşturmak için:

```bash
./scripts/package_dmg.sh
```

Paket şurada oluşur:

```text
dist/ODT Altyazıcı.dmg
```

## Gerekli Bileşenler

Dağıtıma hazır uygulama oluştururken aşağıdaki dosyalar varsa paket içine alınır:

```text
Vendor/Tools/ffmpeg
Vendor/Tools/whisper-cli
Vendor/Models/ggml-large-v3-turbo.bin
```

`whisper-cli` ve gerekli `libwhisper` / `libggml` kütüphanelerini oluşturmak için:

```bash
./scripts/build_whisper_cli.sh
```

Bağımsız bir `ffmpeg` binary'si `Vendor/Tools/ffmpeg` olarak eklenmelidir. Geçici yerel test için sistemdeki `ffmpeg` dosyasını kopyalayan yardımcı:

```bash
./scripts/copy_local_ffmpeg.sh
```

Son dağıtımda Homebrew'e bağlı `ffmpeg` kullanılması önerilmez; başka Mac'lerde eksik kütüphane sorunu çıkarabilir.

## GitHub'a Yüklerken

Bu repoya büyük binary dosyaları eklemeyin.

Repo içinde tutulmaması gerekenler:

- `Vendor/Models/ggml-large-v3-turbo.bin`
- `Vendor/Tools/ffmpeg`
- `Vendor/Tools/whisper-cli`
- `Vendor/Tools/*.dylib`
- `dist/`
- `.build/`
- `.build-tools/`

GitHub normal repo dosyalarında 100 MB üstünü kabul etmez. `large-v3-turbo` modeli yaklaşık 1.5 GB olduğu için repo içine konmamalıdır.

Dağıtım için önerilen yöntem:

1. Kodu GitHub reposuna yükleyin.
2. DMG dosyasını GitHub **Releases** bölümüne asset olarak ekleyin.
3. Model ve binary dosyalarını normal Git geçmişine dahil etmeyin.

## Üçüncü Taraf Bileşenler

Bu uygulama aşağıdaki açık kaynak bileşenlerle çalışır:

- `whisper.cpp`: MIT License
- `ggml-large-v3-turbo.bin`: whisper.cpp GGML model dosyası
- `ffmpeg`: Build seçeneklerine göre LGPL/GPL lisans koşulları geçerli olabilir
- `imageio-ffmpeg`: BSD-2-Clause License, bağımsız ffmpeg binary dağıtımı için kullanılmıştır

Dağıtım yaparken ilgili lisans ve atıf metinlerini korumak önerilir.

## Proje Durumu

Bu proje ilk çalışan prototip aşamasındadır. Ekip içi kullanım için hazırlanmıştır.

Henüz yapılabilecek iyileştirmeler:

- Apple Developer hesabıyla imzalama ve notarization
- Intel Mac için ayrı paket
- Daha gelişmiş hata raporlama
- DMG arka planı ve görsel düzenleme
