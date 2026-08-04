# Çalışma durumu

## Güncel taban

- Yerel çalışan kaynak sürümü GitHub `main` dalına aktarıldı.
- Kaynak, model/binary/DMG dosyalarından ayrı biçimde Git'te izleniyor.
- Video player MVP'si `main` dalına birleştirildi.
- Dağıtım paketi Whisper `large-v3-turbo` modelini içermez. İlk açılışta
  kullanıcı model indirmesini onaylar; araç binary'leri pakette kalır.

## İlk açılışta model indirme — uygulanan

- `package_app.sh`, yerelde `Vendor/Models` altında bulunsa bile 1,5 GB Whisper
  modelini `.app` paketine kopyalamaz.
- İlk açılıştaki kurulum kartı, yaklaşık 1,62 GB indirme, internet/boş alan
  gereksinimi ve tek seferlik kurulum bilgisini açıkça gösterir.
- Mevcut bileşen hazırlama akışı modelin ilerlemesini gösterir ve tamamlanınca
  kullanıcıyı altyazı oluşturma durumuna getirir.

## Video player MVP — uygulanan

- Sağda kalıcı ve `HSplitView` ile yeniden boyutlandırılabilir player paneli.
- `AVPlayerLayer.resizeAspect` ile 9:16, 16:9 ve 1:1 kaynak oranını koruyan oynatma.
- Segment seçimiyle seek ve oynatma zamanına göre aktif segment vurgusu/otomatik kaydırma.
- Oynat/durdur, zaman çubuğu, ses ve 0,5×–2× hız seçimi.
- Önceki/sonraki segment ile Boşluk, ⌥← ve ⌥→ klavye kısayolları.
- Seçili segmentin başlangıç/bitiş zamanını oynatma konumundan ayarlama; geçersiz başlangıç-bitiş sırasını engelleme.
- SRT zaman kodu dönüşümü ve aktif segment seçimi ayrı, deterministik yardımcıya taşındı.

## Doğrulama

- Uygulama hedefi macOS 15.4 SDK ile debug ve release olarak derlendi.
- `scripts/check_srt.sh` ile SRT parse/serialize, zaman kodu dönüşümü ve segment sınırı kontrolleri çalıştı.
- Üretilen 9:16 ve 16:9 MP4 örnekleri gerçek uygulamada kırpılmadan/esnetilmeden açıldı.
- Üretilen 1:1 MP4 örneği gerçek uygulamada siyah bantlar içinde, kaynak oranı korunarak açıldı.
- Dosya geçişi, oynat/durdur ve ilerleyen zaman çubuğu gerçek uygulamada doğrulandı.
- Konuşmalı 9:16 test videosu ile yerel transkripsiyon, oluşan SRT segmentinden seek, oynatma sırasında aktif segment ve düzenlenen SRT'nin diske kaydı uçtan uca doğrulandı.
- Konuşmalı örnekte player 1,286 sn konumundayken segment başlangıcı ayarlandı; SRT dosyasına `00:00:01,287` olarak yazılıp kaydedildi.
- Release `.app` paketi `dist/ODT Altyazıcı.app` altında üretildi.

## Sıradaki doğrulama

- Player çalışma alanı `player-workspace-split-view` erişilebilirlik kimliğiyle
  hedeflenebilir. Son manuel QA turunda minimum pencere genişliğinin üzerindeki
  bir pencerede panel splitter sürüklemesini doğrula. Mevcut UI otomasyonu tam
  ekrana geçişte uygulamayı yeniden başlattığı için bu son sürükleme adımı
  güvenilir biçimde otomatikleştirilemedi.

## Bu turdaki doğrulama notu

- Release `.app` açıldı; player çalışma alanında AppKit `HSplitView` bölücüsü
  erişilebilirlik ağacında görüldü ve geniş pencerede yerleşim korundu.
- Kaynak derlemesi bu makinede doğrulanamadı: seçili Swift derleyicisi ile
  macOS SDK sürümleri uyumsuz, ayrıca kullanıcı düzeyindeki Clang modül önbelleği
  bu çalışma ortamından yazılabilir değil. Bu uygulama kaynak hatası değildir.

## ChatGPT metin araçları — uygulanan

- Doğrudan `ChatGPT Yazım Kontrolü` eylemi, konuşmanın kelimelerini ve akışını
  değiştirmeden yalnızca açık imla/noktalama hatalarını düzeltmesini ister.
- `ChatGPT Araçları` menüsünde metinden ayrı çıktı üreten özet, başlık fikri ve
  video açıklaması eylemleri bulunur.
- Her eylem istemi panoya kopyalar ve ChatGPT'yi açar; uygulamadaki metin
  değiştirilmez.
- `ChatGPTTranscriptAction.swift` type-check ve `ContentView.swift` sözdizimi
  denetiminden geçti. Tüm kaynakların doğrudan `swiftc` type-check'i,
  SwiftPM'in oluşturduğu `Bundle.module` bağlamı olmadan çalıştırılamaz.

## Ürün odağı

- Ana kullanım, yerel transkripsiyonla elde edilen metni sosyal medya üretim
  akışında kullanmaktır; SRT düzenleme destekleyici bir işlevdir.
- README, GitHub portföyünde ürün kararlarını, yerel-öncelikli teknik yaklaşımı
  ve içerik üretim iş akışını gösterecek şekilde güncellendi.

## Kapanış durumu

- Video player, metin odaklı üretim akışı ve ChatGPT metin araçları ürünün
  planlanan son kapsamıdır.
- Yeni özellik geliştirme planlanmıyor; ürün bu sürümüyle tamamlandı.
