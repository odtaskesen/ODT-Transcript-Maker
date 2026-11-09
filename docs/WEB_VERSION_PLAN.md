# Web sürümü planı

Durum: Lite sürüm yazıldı ve önbellekleme sorunu çözüldü. Kullanıcının
kendi Chrome'unda bir kez daha denenmesi bekleniyor.
Tarih: 2026-11-06, güncelleme: 2026-11-09

## Aşamalar

1. **Fizibilite denemesi** — `web/` klasöründe, Mac uygulamasına dokunmadan,
   tek bir test sayfasıyla tarayıcıda `large-v3-turbo` modelinin WebGPU ile
   çalışıp çalışmadığını, hızını ve doğruluğunu ölçmek. Sonuç bu dosyaya ve
   `docs/STATUS.md`'ye yazılır.
2. **Değerlendirme** — Deneme makul hızda ve anlaşılır metin üretiyorsa lite
   kapsamla devam edilir. Üretmiyorsa burada durulup kullanıcıyla birlikte
   yön kararı verilir.
3. **Lite sürüm** — Kapsam bölümündeki özellikler (kuyruk, ilerleme/iptal,
   Metin ve SRT sekmeleri, indirme) uygulanır.
4. **Barındırma/yayın** — Hangi adreste yayınlanacağı gibi kararlar; kod
   yazmayı gerektirmez, ayrıca ele alınır.

## Neden

Mac uygulaması Apple Developer ID ile imzalanmadığı için başkalarına
verildiğinde macOS (Gatekeeper) uygulamayı engelliyor. Developer ID yıllık
99 dolar. Ücretsiz yol olan "sağ tık > Aç" ya da "Yine de Aç" talimatı
her kullanıcıya ayrıca anlatılmak zorunda.

Web sürümünde kurulacak bir program olmadığından bu sorun tamamen ortadan
kalkıyor. Bir link paylaşmak yetiyor.

## Ana fikir

Site yalnızca arayüz görevi görür. Dosyalar hiçbir sunucuya yüklenmez.

1. Kullanıcı siteyi Chrome ya da Edge'de açar.
2. Site ilk kullanımda Whisper modelini bir kez indirir ve tarayıcıda saklar.
   Sonraki açılışlarda tekrar indirmez.
3. Kullanıcı bilgisayarındaki videoları seçer.
4. Yazıya çevirme tamamen kullanıcının bilgisayarında, tarayıcının içinde
   yapılır.
5. Kullanıcı SRT ve TXT dosyalarını indirir.

TurboScribe gibi bir SaaS değil. Hesap, ödeme ve sunucu tarafında işlem yok.

## Kapsam (lite sürüm)

Olacaklar:

- Birden fazla video seçip sıraya sokma. Videolar sırayla işlenir.
- Her video için ilerleme göstergesi ve iptal.
- Biten her video için SRT ve TXT indirme.
- Mac uygulamasındaki gibi iki düzenleme sekmesi:
  - **Metin (varsayılan):** Tüm metin serbestçe düzenlenir. Düzenleme TXT'ye
    yansır.
  - **SRT:** Altyazı satır satır düzenlenir. Yalnızca satırların metni
    değişir, zamanlar sabit kalır.
- Düzenlenmiş halleriyle TXT ve SRT indirme.
- Türkçe arayüz.

Olmayacaklar:

- Video oynatıcı.
- Satıra tıklayınca videonun o ana gitmesi, aktif satırın vurgulanması.

## Teknik yön

- Ayrı, yeni bir proje olarak kurulur. Mac uygulaması olduğu gibi kalır.
- Hedef tarayıcılar Chrome ve Edge. Safari desteklenmez (kullanıcı kararı).
- Model: `large-v3-turbo`.
- whisper.cpp'nin tarayıcı (WASM) sürümü bu model için yeterli değil.
  Yaklaşık 2 GB bellek sınırına takılıyor ve resmi örnek pratikte `small`
  modele kadar çalışıyor.
- Bunun yerine Transformers.js ve ONNX Runtime Web kullanılır. Model
  ekran kartında (WebGPU) çalışır ve büyük model belleğe sığar.
- Model dosyaları whisper.cpp'nin dosyaları değil, ONNX'e dönüştürülmüş
  sürümleri.
- Site sunucuda iş yapmadığı için ücretsiz statik barındırmada yayınlanabilir.

## Riskler ve belirsizlikler

- Bazı Apple Silicon Mac'lerde WebGPU ile topluluk ONNX modellerinin bozuk
  çıktı verdiği bildirilmiş. Bu Mac'te önce denenmeli.
- Tarayıcıda çalışmak Mac uygulamasından büyük ihtimalle daha yavaş olacak.
  Ne kadar yavaş olduğu denemede ölçülmeli.
- İlk açılışta modelin indirilmesi (1-2 GB civarı) birkaç dakika sürebilir.
- Kısa sosyal medya videolarında sorun beklenmiyor. Saatlerce süren ya da çok
  büyük dosyalarda tarayıcının belleği zorlanabilir.

## Açık sorular

- Dil seçimi Mac uygulamasındaki gibi olacak mı (Türkçe, İngilizce, Almanca,
  Felemenkçe, İspanyolca)?
- Site hangi adreste yayınlanacak?

## Deneme sonucu (1. aşama, bu Mac'te)

Test ortamı: `web/spike/` klasöründeki tek sayfalık test, yerel statik
sunucu üzerinden Claude'un kendi tarayıcı panelinde (Chromium tabanlı)
çalıştırıldı. Model: `onnx-community/whisper-large-v3-turbo`,
`encoder_model_fp16` + `decoder_model_merged_q4`, `device: webgpu`.
Test sesi: macOS'un yerleşik Türkçe seslendirmesiyle (Yelda) üretilen,
doğru metni baştan bildiğimiz 19 saniyelik bir konuşma.

- **WebGPU:** Bu Mac'te adapter sorunsuz bulundu, `shader-f16` destekleniyor.
  Bozuk çıktı görülmedi.
- **İlk yükleme:** ~60 saniye (model indirme + "ısınma" dahil).
- **Yazıya çevirme hızı:** 19 saniyelik ses 4,8 saniyede çevrildi — ses
  süresinin yaklaşık 4 katı hızında. Kısa sosyal medya videoları için
  yeterince hızlı görünüyor.
- **Doğruluk:** Metin, beklenen metinle neredeyse birebir eşleşti. İki küçük
  fark vardı ("Altyazıcı" marka adı "altı yazıcı" diye, "hızlı" yerine
  "hızı" yazılmış) — ikisi de TTS'in telaffuzundan kaynaklanıyor olabilir,
  gerçek bir insan kaydında daha az beklenir.
- **Önbellekleme sorunu:** Sayfa yeniden açıldığında model tekrar indirildi
  (yine ~60 sn); beklenen "bir kere indir, bir daha indirme" davranışı bu
  test ortamında çalışmadı. Bu, kullanıcının kendi Chrome'unda ayrıca
  doğrulanmalı — test ortamının (Claude'un tarayıcı paneli) depolamayı
  kalıcı tutmaması da olasılıklardan biri.

**Sonuç:** Hız ve doğruluk açısından deneme başarılı; lite sürüme geçilebilir.
Önbellekleme konusu, lite sürüm yapılırken veya en geç yayın öncesinde
kullanıcının kendi tarayıcısında ayrıca doğrulanmalı.

## Lite sürüm — uygulanan (`web/app/`)

- Dosya seçimi (sürükle-bırak veya tıkla), çoklu dosya kuyruğu, sıralı işleme.
- Model yalnızca ilk dosyada yükleniyor; sıradaki dosyalar için yeniden
  yüklenmiyor (model çalışır durumda kalıyor).
- İşlenirken durum metni ve "İptal et" butonu. İptal, o anki işlemi güvenle
  durdurmak için worker'ı sonlandırıp yeniden başlatıyor; bunun bedeli bir
  sonraki dosya için modelin yeniden yüklenmesi (bkz. önbellekleme sorunu).
- Her biten dosya için ayrı **Metin** (serbest düzenlenebilir, TXT'ye iner)
  ve **SRT** (satır satır düzenlenebilir, zamanlar sabit) sekmesi.
- SRT ayrıştırma/üretme ve zaman kodu dönüşümleri `web/app/srt.mjs`'de,
  `Tests/SRTDocumentChecks`'teki durumlar port edilerek `node
  web/app/check_srt.mjs` ile doğrulanıyor.
- Dil seçimi Mac uygulamasıyla aynı beş dili kapsıyor (Türkçe, İngilizce,
  Almanca, Felemenkçe, İspanyolca).
- Bu Mac'te uçtan uca test edildi: tek dosya, art arda iki dosya (ikincisi
  model yeniden yüklenmeden işlendi), uzun bir dosyada iptal ve ardından
  modelin yeniden yüklenip kuyruğun devam etmesi. Hata konsolda görülmedi.

## Önbellekleme sorunu — bulundu ve çözüldü

Kullanıcı kendi Chrome'unda da aynı sorunu doğruladı: sayfa yeniden
açıldığında model her seferinde yeniden iniyordu. Kök neden bulundu:

Tarayıcıların "Cache Storage" özelliği (sayfaların dosya önbelleklemek için
kullandığı yerleşik depo), Chrome'da tek bir dosya ~250 MB'ı aştığında
"Unexpected internal error" hatasıyla yazmayı reddediyor — bu Mac'te ve
kullanıcının kendi Chrome'unda, 50-900 MB arası dosyalarla ayrı ayrı test
edilip doğrulandı (200 MB'a kadar sorunsuz, 300 MB ve üstü hep başarısız).
Whisper'ın `encoder_model_fp16.onnx` (~1,27 GB) ve
`decoder_model_merged_q4.onnx` (~334 MB) dosyaları bu sınırın üstünde
olduğu için önbelleğe hiç yazılamıyor, her açılışta yeniden iniyordu. Hata
sessizdi (yalnızca tarayıcı konsoluna uyarı yazıyordu), kullanıcıya
görünmüyordu.

**Çözüm:** `web/app/worker.js` içinde, büyük dosyaları ~128 MB'lık
parçalara bölüp her parçayı ayrı bir önbellek kaydı olarak saklayan basit
bir yardımcı (`ChunkedCache`) yazıldı; okurken parçalar birleştiriliyor.
Bu Mac'te doğrulandı: önbellek temizlenip sıfırdan denendiğinde model
~73 saniyede indi (parçalama ek yükü dahil), sayfa yeniden açıldığında ise
yalnızca ~12 saniyede (yeniden indirme olmadan) hazır oldu.

## Sıradaki adım

- Kullanıcının kendi Chrome'unda bu düzeltmeyi bir kez daha denemesi:
  sayfa yeniden açıldığında modelin artık hızlı gelip gelmediği.
- Barındırma/yayın kararı (bkz. Açık sorular).

## Kaynaklar

- [whisper.cpp tarayıcı örneği](https://github.com/fraxy-v/whisper.cpp/blob/master/examples/whisper.wasm)
- [whisper-large-v3-turbo, WebGPU f16 weights](https://huggingface.co/benderrodriguez/whisper-large-v3-turbo-webgpu)
- [whisper large v3 turbo webgpu (striimit)](https://huggingface.co/striimit/whisper-large-v3-turbo-webgpu)
- [Whisper model boyutları](https://openwhispr.com/ja/blog/whisper-model-sizes-explained)
