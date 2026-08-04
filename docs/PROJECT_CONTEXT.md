# Proje bağlamı

## Amaç

ODT Altyazıcı, sosyal medya üretim akışlarında video ve ses dosyalarını terminal
kullanmadan düzenlenebilir metne dönüştüren yerel bir macOS uygulamasıdır.
SRT ve TXT çıktısı üretebilir; ancak ana kullanım, konuşma metnini videocuya,
içerik planına veya paylaşım hazırlığına aktarmaktır. Uygulama içinde metin ve
SRT segmentleri düzenlenebilir.

## Mevcut mimari

- `Sources/ODTAltyazici/ContentView.swift`: SwiftUI arayüzü, dosya kuyruğu,
  editör durumu ve kullanıcı akışları.
- `Sources/ODTAltyazici/TranscriptionService.swift`: FFmpeg ile ses hazırlama,
  Whisper çalıştırma, canlı ilerleme/segment olayları ve çıktı yazımı.
- `Sources/ODTAltyazici/ComponentInstaller.swift`: araç ve model hazırlığı.
- `scripts/package_app.sh` ve `scripts/package_dmg.sh`: uygulama/DMG paketi.

Whisper modeli `large-v3-turbo`dur ve Apple Silicon Metal hızlandırmasıyla
çalışır. Büyük model ve araç binary'leri Git dışında tutulur.

## Korunacak davranışlar

- Çoklu dosya kuyruğu sıralı işlenir.
- Kullanıcı işlem sırasında ilerleme, canlı metin ve iptal seçeneği görür.
- SRT/TXT kaydı mevcut dosyanın üzerine yazmadan önce onay ister.
- Kaydedilmemiş düzenlemeler kaybolmadan önce kullanıcı uyarılır.
- Metin odaklı akış, SRT düzenleme işlevlerinden bağımsız olarak hızlı ve
  kullanılabilir kalır.

## Uygulanan video player

Player sağ tarafta ayrı bir çalışma paneli olarak uygulandı. Tasarım 9:16
videoyu önceliklendirir; kaynak oranı korunur. Player, SRT segmentiyle çift
yönlü senkron çalışır: segmente tıklama ilgili zamana gider, oynatma aktif
segmenti vurgular.

Dalga formu, altyazıyı MP4'e gömme ve uygulama içinde çalışan bir AI düzeltme
nihai ürün kapsamı dışındadır.

## ChatGPT metin araçları

Uygulama metni kendisi değiştirmez veya buluta kaydetmez. Kullanıcının açık
eylemiyle seçilen ChatGPT istemi panoya kopyalanır ve ChatGPT açılır; kullanıcı
isterse metni kendi ChatGPT projesine yapıştırır. Yazım kontrolü istemi
konuşmanın kelimelerini ve üslubunu korur; özet, başlık fikri ve açıklama
istemleri ayrı çıktılar üretir.

## Kapanış durumu

Bu belge, ürünün son kapsamını kaydeder. Yeni özellik geliştirme planlanmıyor;
bundan sonraki çalışma yalnızca mevcut ürünün gerektiğinde bakımını kapsar.
