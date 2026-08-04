import Foundation

enum ChatGPTTranscriptAction: CaseIterable, Hashable, Identifiable {
    case spellingCheck
    case summary
    case titleIdeas
    case description

    var id: Self { self }

    var title: String {
        switch self {
        case .spellingCheck:
            "ChatGPT Yazım Kontrolü"
        case .summary:
            "Özet Çıkar"
        case .titleIdeas:
            "Başlık Fikirleri"
        case .description:
            "Açıklama Yazdır"
        }
    }

    var systemImage: String {
        switch self {
        case .spellingCheck:
            "text.badge.checkmark"
        case .summary:
            "list.bullet.rectangle"
        case .titleIdeas:
            "text.bubble"
        case .description:
            "text.document"
        }
    }

    var copiedMessage: String {
        "\(title) için kopyalandı"
    }

    func prompt(for transcript: String) -> String {
        let instruction: String

        switch self {
        case .spellingCheck:
            instruction = """
            Aşağıdaki konuşma metninde yalnızca açık yazım, imla, büyük/küçük harf ve noktalama hatalarını düzelt.

            Konuşanın söylediği kelimeleri, cümle sırasını, üslubunu ve anlamını kesinlikle değiştirme.
            Cümleleri yeniden yazma, sadeleştirme, akıcılaştırma, kısaltma veya genişletme yapma.
            Tekrarları, dolgu kelimelerini ve konuşma dilindeki ifadeleri olduğu gibi koru.
            Bağlamdan tahmin ederek kelime değiştirme; emin değilsen metni olduğu gibi bırak.

            Yalnızca düzeltilmiş metni ver. Açıklama, başlık, not veya öneri ekleme.

            Metin:
            """
        case .summary:
            instruction = """
            Aşağıdaki konuşma metnini özetle.

            Önemli noktaları 5–8 kısa madde hâlinde yaz.
            Konuşma metnini değiştirme; yalnızca ayrı bir özet üret.

            Metin:
            """
        case .titleIdeas:
            instruction = """
            Aşağıdaki konuşma metni için 15 video başlığı öner.

            Başlıklar kısa, doğal ve merak uyandırıcı olsun.
            Aşırı clickbait, emoji ve tamamı büyük harf kullanma.
            Yalnızca numaralandırılmış başlık listesini ver.

            Konuşma metni:
            """
        case .description:
            instruction = """
            Aşağıdaki konuşma metnine dayanarak video için bir açıklama yaz.

            Hashtag, emoji, başlık veya “abone olun” çağrısı ekleme.
            Yalnızca açıklama metnini ver.

            Konuşma metni:
            """
        }

        return "\(instruction)\n\n\(transcript)"
    }
}
