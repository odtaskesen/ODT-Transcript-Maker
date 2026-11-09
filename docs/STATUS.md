# Çalışma durumu

## Web sürümü — "eski sürümde takılı kalma" hatası bulundu ve çözüldü (yeni)

- Yayına alınan sitede (odtaltyazici.vercel.app) kullanıcı, kurulum
  banner'ındaki kapatma (×) butonunun çalışmadığını bildirdi.
- Kök neden: servis çalışanının eski sürümü, yeni bir deploy sonrasında
  da sekme kapatılıp açılana kadar sayfayı kontrol etmeye devam ediyor
  (servis çalışanlarının normal yaşam döngüsü) — kullanıcı farkında
  olmadan eski, düzeltilmemiş `app.js`'i görüyordu. Temiz bir oturumda
  (önbellek/servis çalışanı sıfırlanmış) buton sorunsuz çalıştığı
  doğrulanarak teyit edildi.
- Çözüm: `sw.js`'e sürümlü önbellek adı ve kurulum sırasında dosyaları
  tarayıcı HTTP önbelleğini atlayıp ağdan taze alma eklendi; `app.js`'e
  yeni bir servis çalışanı devreye girdiğinde kullanıcıya "Sayfanın yeni
  bir sürümü hazır — Yenile" çağrısı gösteren bir bildirim eklendi.
- Canlı sitede uçtan uca doğrulandı: eski sürümü kontrol eden bir sekme
  yenilenince yeni sürüme (v2 önbellek) geçti, kapatma butonu çalıştı.
- Ayrıca `chatgpt-prompts.mjs` önbellek listesine eklendi (unutulmuştu).

## Web sürümü — çevrimdışı (PWA) + ChatGPT araçları eklendi

- Sayfa artık uygulama olarak kurulabiliyor (manifest + servis
  çalışanı); kurulduktan sonra internetsiz de açılıyor. Kullanıcının
  kendi Chrome'unda doğrulandı: servis çalışanı "activated and
  running", wifi kapalıyken de sayfa açıldı.
- Sayfada, tarayıcı kurulabilir dediğinde beliren, kapatılabilir bir
  "Uygulama olarak yükle" çağrısı var (ok işaretiyle tarayıcının kendi
  simgesine gönderme yapıyor).
- Mac uygulamasındaki dört ChatGPT istemi (Yazım Kontrolü, Özet Çıkar,
  Başlık Fikirleri, Açıklama Yazdır) web sürümüne de eklendi; kullanıcı
  test etti, çalışıyor.
- `main`'e commit'lendi ve push edildi.

## Web sürümü — `main`'e merge edildi, Vercel'e hazır

- `feature/web-lite-spike` dalındaki tüm iş (fizibilite denemesi, lite
  sürüm, önbellekleme düzeltmesi, tasarım dili) PR #1 ile `main`'e
  merge edildi.
- Vercel bağlanırken Root Directory **`web/app`** olarak ayarlanmalı
  (yalnızca o klasör yayına hazır; `web/spike` atılabilir bir denemedir,
  `web/design-reference` zaten repoda yok).

## Web sürümü — tasarım dili uygulandı

- Kullanıcının referansı (makingsoftware.com stil analizi) sayfaya
  uygulandı: Paper/Ink/Blueprint Blue palet, EB Garamond (serif, Arizona
  ikamesi) + Departure Mono (yerelde barındırılan, SIL OFL), noktalı
  bölücüler, dot-leader'lar, iç gölgeli "key button". Kırmızı/yeşil durum
  rengi eklenmedi (tek vurgu rengi kuralına uyuldu).
- Departure Mono'nun Türkçe karakterleri (İŞĞÇÖÜ) piksel karşılaştırmasıyla
  doğrulandı; büyük harfe çevirme CSS ile yapılıyor, JS'de
  `.toUpperCase()` yok.
- Model indirme ilerlemesi artık tek, sıçramayan bir çubukla gösteriliyor
  (kütüphanenin "progress_total" toplama olayı kullanılarak); "diskten mi
  geldi, internetten mi indi" ayrımı da artık kullanıcıya doğru yazılıyor.
- Bu Mac'te görsel olarak test edildi: boş durum, ilerleme, tamamlanmış
  sekmeler, hata, iptal, 375px mobil genişlik.
- `web/design-reference/` (kullanıcının verdiği üçüncü taraf stil
  dosyaları) `.gitignore`'a eklendi, repoya girmiyor.
- Ayrıntı: `docs/WEB_VERSION_PLAN.md` → "Tasarım dili — uygulanan".

## Web sürümü — önbellekleme hatası bulundu ve çözüldü

- Kullanıcı kendi Chrome'unda denedi: sayfa yeniden açılınca model yine
  baştan indi, lite sürümdeki açık sorun doğrulandı.
- Kök neden bulundu: Chrome'un Cache Storage'ı tek dosya ~250 MB'ı
  aştığında "Unexpected internal error" ile sessizce başarısız oluyor
  (bu Mac'te 50-900 MB arası dosyalarla ölçülüp doğrulandı). Whisper'ın
  büyük `encoder`/`decoder` dosyaları bu sınırın üstünde.
- Çözüm: `web/app/worker.js`'e büyük dosyaları ~128 MB'lık parçalara
  bölüp ayrı ayrı önbellekleyen bir yardımcı (`ChunkedCache`) eklendi.
- Doğrulama (bu Mac'te): önbellek temizlenip yeniden denendiğinde ilk
  yükleme ~73 sn (parçalama ek yüküyle), sayfa yeniden açıldığında ise
  ~12 sn'de (yeniden indirme olmadan) hazır oldu.
- Doğrulama (kullanıcının kendi Chrome'unda): ilk yükleme ~70 sn, sayfa
  yenilendiğinde ~9-10 sn — düzeltme gerçek kullanımda da çalışıyor.
- Ayrıntı: `docs/WEB_VERSION_PLAN.md` → "Önbellekleme sorunu — bulundu ve
  çözüldü".
- Kapanış durumu: teknik fizibilite tamamlandı. Kalan konu yalnızca
  barındırma/yayın kararı.

## Web sürümü — fizibilite denemesi (yeni)

- `feature/web-lite-spike` dalında, ayrı bir `web/spike/` klasöründe tek
  sayfalık bir test kuruldu. Mac uygulamasına dokunulmadı.
- Test: `onnx-community/whisper-large-v3-turbo` modeli, tarayıcıda WebGPU
  üzerinden (Transformers.js, encoder fp16 + decoder q4), macOS'un Türkçe
  seslendirmesiyle üretilen 19 saniyelik bir test sesiyle çalıştırıldı.
- Sonuç: WebGPU bu Mac'te sorunsuz çalıştı, bozuk çıktı yok. Çevirme hızı
  ses süresinin ~4 katı (19 sn ses, 4,8 sn'de çevrildi). Çıkan metin beklenen
  metinle neredeyse birebir eşleşti (iki küçük TTS kaynaklı fark dışında).
- Açık konu: model önbellekte kalıcı kalmadı, sayfa yeniden açılınca tekrar
  indirildi. Kullanıcının kendi Chrome'unda ayrıca doğrulanmalı.
- Ayrıntı ve tam ölçümler: `docs/WEB_VERSION_PLAN.md` → "Deneme sonucu".
- Karar: hız/doğruluk yeterli görüldüğü için lite web sürümünün yapımına
  geçildi.

## Web sürümü — lite sürüm ilk hali (yeni)

- `web/app/` altında, derleme aracı gerektirmeyen bir web uygulaması
  yazıldı: dosya kuyruğu, sıralı işleme, Metin/SRT düzenleme sekmeleri,
  TXT/SRT indirme, beş dilli seçim (Mac uygulamasıyla aynı).
- SRT yardımcıları (`web/app/srt.mjs`) `Tests/SRTDocumentChecks`'teki
  durumlar port edilerek `web/app/check_srt.mjs` ile doğrulandı.
- Bu Mac'te uçtan uca denendi: tek dosya, çoklu kuyruk (model yeniden
  yüklenmeden), ve işlem sırasında iptal + modelin yeniden yüklenip
  kuyruğun devam etmesi. Konsolda hata görülmedi.
- Doğrulanmayan konu: kullanıcının kendi Chrome'unda önbellekleme
  davranışı (fizibilite denemesindeki önbellek sorununun gerçek
  kullanımda da geçerli olup olmadığı).
- Ayrıntı: `docs/WEB_VERSION_PLAN.md` → "Lite sürüm — uygulanan".

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
- Xcode 26.6 ile release uygulaması derlendi; model içermeyen `.app` 52 MB ve
  doğrulanmış `.dmg` 24 MB olarak üretildi.
- `scripts/check_srt.sh` başarılı çalıştı; oluşturulan uygulama paketinde
  `Resources/Models/ggml-large-v3-turbo.bin` bulunmadığı kontrol edildi.

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
