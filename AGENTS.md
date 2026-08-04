# ODT Altyazıcı — Codex çalışma rehberi

## Oturum handoff'u

Bu kurallar her yeni Codex sohbetinde kendiliğinden uygulanır; kullanıcıdan
yeniden istemesini bekleme.

### Başlangıçta

Bir geliştirmeye başlamadan önce `README.md`, `docs/PROJECT_CONTEXT.md` ve
`docs/STATUS.md` dosyalarını oku. Ardından `git status` ve son üç commit'i,
sonra da ilgili kaynak dosyalarını incele. Uygulamanın çalışma mantığını
yalnızca ekran görüntüsünden değil, önce kaynak koddan değerlendir.

### Bitirirken

Kod, ürün kararı veya doğrulama durumu değiştiyse `docs/STATUS.md` dosyasını
yapılanlar, doğrulama ve sıradaki adımlarla güncelle. Kalıcı mimari/ürün
kararlarını yalnızca gerektiğinde `docs/PROJECT_CONTEXT.md` dosyasına ekle;
genel Codex çalışma kuralları değişmedikçe `AGENTS.md`yi güncelleme. İlgili
dosyaları mantıklı, küçük bir committe kaydet ve GitHub'a gönder; beklenmeyen
dış etki, silme veya erişim genişletme gerektiren durumlarda kullanıcıya sor.

## Ürün ilkeleri

- Bu, Apple Silicon için yerel çalışan bir macOS SwiftUI uygulamasıdır.
- Transkripsiyon yerelde `ffmpeg` ve `whisper.cpp` ile yapılır; varsayılan
  işleyiş için bulut servisi veya yeni üçüncü taraf bağımlılığı ekleme.
- Kullanıcının video, ses ve altyazı dosyaları yerel kalmalıdır.
- Arayüz dili Türkçedir; kullanıcıya gösterilen yeni metinler Türkçe olmalıdır.
- Mevcut kuyruk, canlı ilerleme, iptal, SRT/TXT düzenleme ve kayıt güvenliği
  davranışlarını geriletme.

## Video player kararı

- Player çalışma alanının sağında, ayrı ve kalıcı bir paneldir.
- Öncelik 9:16 dikey videolardır; 16:9 ve 1:1 de desteklenir.
- Video gerçek en-boy oranını korur; kırpılmaz veya esnetilmez.
- Player bir izleme eklentisi değil, SRT segment düzenleme aracıdır:
  segment seçimi videoyu ilgili zamana götürür; oynatma aktif segmenti belirtir.

## Kod ve doğrulama

- Yeni, ayrı sorumluluğu olan kodu yeni Swift dosyalarına ayır; `ContentView`
  dosyasını gereksiz büyütme.
- SRT zaman hesaplamaları ve parse/serialize davranışı için deterministik,
  test edilebilir yardımcılar kullan.
- Büyük dosyaları (`Vendor` binary'leri, model, `dist`, `.build`) Git'e ekleme.
- Hedefli doğrulama yap: derleme, SRT kaydetme ve 9:16/16:9 player akışı.
- Derleme hatası yerel Xcode/SDK uyuşmazlığından kaynaklanıyorsa bunu uygulama
  hatası diye raporlama; doğrulama kapsamını açıkça belirt.

## Git çalışma biçimi

- `main` yalnızca çalışır ve gözden geçirilmiş durumları taşımalıdır.
- Her özellik için `feature/...` dalı kullan.
- Commitler küçük ve tek amaçlı olsun: `feat(player): ...`, `fix(srt): ...`,
  `docs: ...`.
- Bir aşama tamamlandığında `docs/STATUS.md` dosyasını güncelle ve ilgili
  kaynak değişikliğiyle aynı committe kaydet.
