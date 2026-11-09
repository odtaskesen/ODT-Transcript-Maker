// Mac uygulamasındaki ChatGPTTranscriptAction.swift ile aynı istemler.

export const CHATGPT_ACTIONS = [
  {
    id: "spellingCheck",
    title: "Yazım Kontrolü",
    copiedMessage: "Yazım Kontrolü için kopyalandı",
    instruction: `Aşağıdaki konuşma metninde yalnızca açık yazım, imla, büyük/küçük harf ve noktalama hatalarını düzelt.

Konuşanın söylediği kelimeleri, cümle sırasını, üslubunu ve anlamını kesinlikle değiştirme.
Cümleleri yeniden yazma, sadeleştirme, akıcılaştırma, kısaltma veya genişletme yapma.
Tekrarları, dolgu kelimelerini ve konuşma dilindeki ifadeleri olduğu gibi koru.
Bağlamdan tahmin ederek kelime değiştirme; emin değilsen metni olduğu gibi bırak.

Yalnızca düzeltilmiş metni ver. Açıklama, başlık, not veya öneri ekleme.

Metin:`,
  },
  {
    id: "summary",
    title: "Özet Çıkar",
    copiedMessage: "Özet Çıkar için kopyalandı",
    instruction: `Aşağıdaki konuşma metnini özetle.

Önemli noktaları 5–8 kısa madde hâlinde yaz.
Konuşma metnini değiştirme; yalnızca ayrı bir özet üret.

Metin:`,
  },
  {
    id: "titleIdeas",
    title: "Başlık Fikirleri",
    copiedMessage: "Başlık Fikirleri için kopyalandı",
    instruction: `Aşağıdaki konuşma metni için 15 video başlığı öner.

Başlıklar kısa, doğal ve merak uyandırıcı olsun.
Aşırı clickbait, emoji ve tamamı büyük harf kullanma.
Yalnızca numaralandırılmış başlık listesini ver.

Konuşma metni:`,
  },
  {
    id: "description",
    title: "Açıklama Yazdır",
    copiedMessage: "Açıklama Yazdır için kopyalandı",
    instruction: `Aşağıdaki konuşma metnine dayanarak video için bir açıklama yaz.

Hashtag, emoji, başlık veya "abone olun" çağrısı ekleme.
Yalnızca açıklama metnini ver.

Konuşma metni:`,
  },
];

export function buildPrompt(action, transcript) {
  return `${action.instruction}\n\n${transcript}`;
}
