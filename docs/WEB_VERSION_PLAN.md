# Web sürümü planı

Durum: Fizibilite denemesi bu Mac'te başarılı. 2. aşamaya (lite sürüm) geçilebilir.
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
- Model önbellekte gerçekten kalıcı kalıyor mu? Deneme ortamında kalmadığı
  görüldü (bkz. Deneme sonucu). Kullanıcının kendi Chrome'unda doğrulanmalı.

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

## Sıradaki adım

Lite sürümün yapımına başlandı (bkz. `web/` klasörü). Kapsam bölümündeki
özellikler sırayla uygulanacak.

## Kaynaklar

- [whisper.cpp tarayıcı örneği](https://github.com/fraxy-v/whisper.cpp/blob/master/examples/whisper.wasm)
- [whisper-large-v3-turbo, WebGPU f16 weights](https://huggingface.co/benderrodriguez/whisper-large-v3-turbo-webgpu)
- [whisper large v3 turbo webgpu (striimit)](https://huggingface.co/striimit/whisper-large-v3-turbo-webgpu)
- [Whisper model boyutları](https://openwhispr.com/ja/blog/whisper-model-sizes-explained)
