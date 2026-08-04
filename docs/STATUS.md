# Çalışma durumu

## Güncel taban

- Yerel çalışan kaynak sürümü GitHub `main` dalına aktarıldı.
- Kaynak, model/binary/DMG dosyalarından ayrı biçimde Git'te izleniyor.
- Player geliştirmesi `feature/video-player-mvp` dalında sürüyor.

## Video player MVP — uygulanan

- Sağda kalıcı ve `HSplitView` ile yeniden boyutlandırılabilir player paneli.
- `AVPlayerLayer.resizeAspect` ile 9:16, 16:9 ve 1:1 kaynak oranını koruyan oynatma.
- Segment seçimiyle seek ve oynatma zamanına göre aktif segment vurgusu/otomatik kaydırma.
- Oynat/durdur, zaman çubuğu, ses ve 0,5×–2× hız seçimi.
- Önceki/sonraki segment ile Boşluk, ⌥← ve ⌥→ klavye kısayolları.
- SRT zaman kodu dönüşümü ve aktif segment seçimi ayrı, deterministik yardımcıya taşındı.

## Doğrulama

- Uygulama hedefi macOS 15.4 SDK ile debug ve release olarak derlendi.
- `scripts/check_srt.sh` ile SRT parse/serialize, zaman kodu dönüşümü ve segment sınırı kontrolleri çalıştı.
- Üretilen 9:16 ve 16:9 MP4 örnekleri gerçek uygulamada kırpılmadan/esnetilmeden açıldı.
- Üretilen 1:1 MP4 örneği gerçek uygulamada siyah bantlar içinde, kaynak oranı korunarak açıldı.
- Dosya geçişi, oynat/durdur ve ilerleyen zaman çubuğu gerçek uygulamada doğrulandı.
- Konuşmalı 9:16 test videosu ile yerel transkripsiyon, oluşan SRT segmentinden seek, oynatma sırasında aktif segment ve düzenlenen SRT'nin diske kaydı uçtan uca doğrulandı.
- Release `.app` paketi `dist/ODT Altyazıcı.app` altında üretildi.

## Sıradaki doğrulama

- Son manuel QA turunda, minimum pencere genişliğinin üzerindeki bir pencerede panel splitter sürüklemesini doğrula. Otomasyon işaretçiyi bölücüye taşıdı; ancak mevcut minimum genişlikte konum değişimini gözlemlemek mümkün olmadı.

## İlk sürüm sonrası

- Başlangıç/bitiş zamanını oynatma konumundan ayarlama.
- Segment bölme, birleştirme ve kalite uyarıları.
- Dalga formu ve videoya altyazı gömme, ayrı kapsam olarak değerlendirilir.
