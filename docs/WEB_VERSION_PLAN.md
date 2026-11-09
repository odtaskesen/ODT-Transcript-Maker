# Web sürümü planı

Durum: Lite sürüm yazıldı, önbellekleme sorunu çözüldü (kullanıcının
Chrome'unda doğrulandı), sayfaya bir tasarım dili uygulandı, çevrimdışı
çalışma (PWA) ve Hafif/Optimal model modu eklendi.
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
"Unexpected internal error" hatasıyla yazmayı reddediyor — bu sınır bu
Mac'te, 50-900 MB arası dosyalarla ayrı ayrı test edilip ölçüldü (200 MB'a
kadar sorunsuz, 300 MB ve üstü hep başarısız). Kullanıcının kendi
Chrome'unda doğrulanan, aynı belirtinin (model her açılışta yeniden inme)
orada da görülmesiydi; tam MB sınırı yalnızca bu Mac'te ölçüldü.
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

**Kullanıcının kendi Chrome'unda doğrulama:** İlk yükleme ~70 saniye
(indirme), sayfa yenilendiğinde ~9-10 saniye (yeniden indirme yok —
dosyalar diskten okunuyor, yalnızca ekran kartının "ısınması" sürüyor).
Düzeltme gerçek kullanımda da çalışıyor.

## Tasarım dili — uygulanan

Kullanıcının verdiği referans (makingsoftware.com'un stil analizi,
`web/design-reference/` — bu klasör üçüncü taraf materyali olduğu için
repoya eklenmedi, `.gitignore`'da) sayfaya uygulandı:

- Renkler ve tipografi: Paper #fbfbfb zemin, Ink #000000 metin, Blueprint
  Blue #103dff tek vurgu rengi, Ash Gray #7d7d7d ikincil bilgiler için.
  Gövde metni serif (Arizona'nın lisanssız olması nedeniyle belirtilen
  ikame EB Garamond, Google Fonts), başlık/etiket/buton metni Departure
  Mono (SIL OFL lisanslı, `web/app/fonts/` altında yerelde barındırılıyor,
  lisans dosyasıyla birlikte).
- Bileşenler: noktalı kesik çizgi bölücüler, dipnot stili "dot leader"
  (dosya adı ... durum), köşeli/az yuvarlak kartlar, iç gölgeli "key
  button" (buton dolgusu yok, ince çerçeve).
- Uyarlamalar: orijinal sayfa uzun bir makale; bu bir araç olduğu için
  256px bölüm boşlukları gibi ölçüler küçültüldü, kırmızı/yeşil durum
  renkleri eklenmedi (marka dilinde ikinci bir renk yok kuralına uyuldu;
  hata/iptal durumları Ink/Ash Gray ve düz metinle anlatılıyor).
- Departure Mono'nun Türkçe karakterleri (İ Ş Ğ Ç Ö Ü ı ş ğ ç ö ü)
  kapsadığı, piksel karşılaştırmasıyla doğrulandı. Büyük harfe çevirme
  CSS `text-transform: uppercase` ile yapılıyor (`lang="tr"` sayesinde
  Chrome "i" harfini doğru şekilde noktalı "İ" yapıyor); JS tarafında
  `.toUpperCase()` kullanılmadı.
- Model yükleme ilerlemesi artık Transformers.js'in kendi "progress_total"
  toplama olayı kullanılarak tek, sıçramayan bir çubukla (█░ karakterleri,
  Blueprint Blue) gösteriliyor; önceden her dosyada sıfırlanıyordu.
- Model durumunun diskten mi geldiği, internetten mi indiği artık ayrı
  ayrı söyleniyor ("Model diskten yüklendi" / "Model indirildi ve
  hazırlandı") — önceki sürüm ikisini de "indiriliyor" diye gösteriyordu.
- Bu Mac'te görsel olarak test edildi: boş durum, kuyruğa ekleme, ilerleme
  çubuğu, tamamlanmış Metin/SRT sekmeleri, hata durumu (bozuk dosya),
  iptal durumu, 375px mobil genişlik. Hepsi beklendiği gibi çalıştı.

## Çevrimdışı çalışma (PWA) — uygulanan

- `web/app/manifest.webmanifest` + `web/app/sw.js`: sayfa "uygulama
  olarak yükle" ile kurulabiliyor, servis çalışanı uygulama kabuğunu
  (model hariç) önbelleğe alıyor. Kullanıcının kendi Chrome'unda
  doğrulandı: wifi kapalıyken de sayfa açıldı.
- Sayfa içi "uygulama olarak yükle" çağrısı (banner + ok) kullanıcı
  isteğiyle kaldırıldı — Chrome zaten adres çubuğunda kendi kurulum
  simgesini gösteriyor, ayrı bir çağrıya gerek görülmedi.
- "Sayfanın yeni bir sürümü hazır — Yenile" bildirimi kaldı: servis
  çalışanı güncellenince kullanıcıyı eski, önbellekte takılı kalmış bir
  sürümde bırakmamak için. Canlı sitede uçtan uca doğrulandı.

## Hafif/Optimal mod — uygulanan

Zayıf bilgisayarlarda büyük modelin yavaş kalabileceği düşünülerek,
"Dil" seçiminin altına bir model modu eklendi:

- **Optimal** (varsayılan): `onnx-community/whisper-large-v3-turbo`,
  ~1,6 GB.
- **Hafif**: `onnx-community/whisper-small`, ~400 MB.

Karar, OpenAI'ın Whisper makalesindeki Common Voice 9 Türkçe hata
oranlarına dayanıyor (Tablo 11, düşük = iyi):

| Model | Hata oranı |
|---|---|
| tiny | %53,6 |
| base | %38,6 |
| small | %23,7 |
| medium | %17,7 |
| large | %16,6 |
| large-v2 | %14,5 |

tiny ve base, Türkçe için kullanılamayacak kadar kötü çıktığından
listeye alınmadı; `small`, boyut/hız kazancı karşılığında "kullanılabilir
ama belirgin ölçüde daha hatalı" tek makul seçenek.

Bu Mac'te uçtan uca test edildi: Hafif modda `whisper-small` indi
(~20 sn), Optimal'e dönünce `whisper-large-v3-turbo` doğru şekilde
yeniden indirilmeye başladı. Hafif modun çıktısında beklenen fazladan
hatalar gözlemlendi (örn. "ODT Altyazıcı" → "O DTA 6 yazıcı").

## Sıradaki adım

Barındırma/yayın kararı (bkz. Açık sorular). Teknik taraf (fizibilite +
lite sürüm + önbellekleme + tasarım + PWA + mod seçimi) tamamlandı.

## Kaynaklar

- [whisper.cpp tarayıcı örneği](https://github.com/fraxy-v/whisper.cpp/blob/master/examples/whisper.wasm)
- [whisper-large-v3-turbo, WebGPU f16 weights](https://huggingface.co/benderrodriguez/whisper-large-v3-turbo-webgpu)
- [whisper large v3 turbo webgpu (striimit)](https://huggingface.co/striimit/whisper-large-v3-turbo-webgpu)
- [Whisper model boyutları](https://openwhispr.com/ja/blog/whisper-model-sizes-explained)
