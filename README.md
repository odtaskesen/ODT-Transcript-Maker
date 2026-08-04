# ODT Altyazıcı

**Yerel çalışan macOS transkripsiyon ve içerik hazırlama aracı.** Sosyal medya
üretiminde video veya ses kayıtlarını hızlıca düzenlenebilir metne dönüştürmek;
ardından o metinden doğru yazılmış bir döküm, özet, başlık fikri veya video
açıklaması üretmek için geliştirdim.

Bu proje, sadece bir altyazı üreticisinden ziyade içerik üretim akışındaki
manuel ve dağınık adımları tek bir masaüstü arayüzünde toplama yaklaşımımı
gösterir: dosya seçimi, yerel transkripsiyon, metin düzenleme, güvenli kayıt ve
ChatGPT'ye kontrollü içerik hazırlama istemleri.

## Neyi çözüyor?

Bir sosyal medya videosunun ham kaydından sonra içerik ekibinin genellikle
önce konuşma metnine ihtiyacı olur. ODT Altyazıcı bu metni terminal, bulut
zorunluluğu veya dağınık araç geçişleri olmadan üretir. Metin; videocuya kesit
notu iletmek, içerik fikri çıkarmak veya paylaşım hazırlamak için doğrudan
kullanılabilir.

Varsayılan transkripsiyon akışı tamamen yereldir. ChatGPT araçları isteğe
bağlıdır: uygulama istemi yalnızca panoya kopyalar ve ChatGPT'yi açar; metni
otomatik olarak göndermez ya da uygulama içinde değiştirmez.

## Ürün özellikleri

### Yerel transkripsiyon

- Native SwiftUI macOS arayüzü ve sürükle-bırak dosya seçimi
- Apple Silicon Metal hızlandırmalı `large-v3-turbo` Whisper modeli
- Türkçe, İngilizce, Almanca, Felemenkçe ve İspanyolca desteği
- `.txt` ve `.srt` çıktı seçimi; çoklu dosya kuyruğu, canlı ilerleme ve iptal
- İşlem sürerken canlı metin, süre/kalan süre tahmini ve tamamlanma özeti

### Metinle çalışma

- Metin içinde arama, düzenleme, panoya kopyalama ve güvenli `.txt` kaydı
- Kaydedilmemiş değişiklik ve mevcut dosyanın üstüne yazma için koruyucu onaylar
- Son kullanılan klasörü hatırlama; sonuç klasörünü Finder'da açma
- SRT segment düzenleme, kaydetme ve oran koruyan video player ile zaman senkronu

### İçerik üretim araçları

- **ChatGPT Yazım Kontrolü:** Konuşmanın kelimelerini, üslubunu ve akışını
  koruyarak yalnızca açık imla/noktalama düzeltmesi ister.
- **Özet Çıkar:** Uzun konuşmadan ayrı, kısa bir özet üretir.
- **Başlık Fikirleri:** Konuşma metni üzerinden video başlığı önerileri hazırlar.
- **Açıklama Yazdır:** Metinden ayrı bir video açıklaması üretir.

Bu eylemler uygulama içindeki metni değiştirmez. İstemler panoya kopyalanır;
kullanıcı ChatGPT'de kendi çalışma alanı ve proje bağlamıyla devam eder.

## Örnek iş akışı

1. Video veya ses kaydını uygulamaya sürükle.
2. Yerel transkripsiyon bitene kadar ilerlemeyi canlı izle.
3. Düzenlenebilir metni gözden geçir, gerekiyorsa `.txt` olarak kaydet veya kopyala.
4. Yazım kontrolü, özet, başlık veya açıklama için uygun ChatGPT aracını seç.
5. Çıktıyı içerik planında, videocu iletişiminde veya paylaşım hazırlığında kullan.

## Teknik yaklaşım

- **Uygulama:** Swift 6, SwiftUI ve AppKit
- **Medya:** AVFoundation player, FFmpeg ile ses hazırlama
- **Transkripsiyon:** Yerel `whisper.cpp`, `large-v3-turbo` ve Apple Silicon Metal
- **Veri yaklaşımı:** Video, ses ve altyazı dosyaları varsayılan olarak cihazda kalır
- **Kullanıcı deneyimi:** Kuyruk, canlı durum, iptal, güvenli kayıt ve geri
  dönüşü mümkün arayüz davranışları

Bu kararlar; içerik üretimi gibi hızlı teslim gerektiren işlerde kullanıcıyı
tarayıcı, terminal ve birden fazla dosya arasında dolaştırmayan, güvenilir bir
masaüstü deneyimi hedefler.

## Kullanım

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

## Proje durumu ve sonraki adımlar

Video player MVP'si tamamlandı. Bir sonraki ürün kararları, gerçek kullanımda
en fazla zaman kazandıran ihtiyaçlara göre verilecek. Dağıtım kalitesini
artırmak için Apple Developer hesabıyla imzalama/notarization, daha gelişmiş
hata raporlama ve DMG görsel düzenlemesi ayrıca değerlendirilebilir.
