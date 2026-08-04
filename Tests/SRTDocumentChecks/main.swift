import Foundation

@main
enum SRTDocumentChecks {
    static func main() {
        parsesAndSerializesMultilineSegments()
        convertsValidTimecodesDeterministically()
        serializesTimecodesDeterministically()
        findsActiveSegmentUsingHalfOpenTimeRange()
        print("SRT doğrulamaları başarılı.")
    }

    private static func parsesAndSerializesMultilineSegments() {
        let raw = """
        1
        00:00:01,250 --> 00:00:03,500
        İlk satır
        ikinci satır

        2
        00:01:02.000 --> 00:01:04.125
        Sonraki segment

        """

        let segments = SRTDocument.parse(raw)

        expect(segments.count == 2, "İki segment parse edilmeliydi.")
        expect(segments[0].text == "İlk satır\nikinci satır", "Çok satırlı metin korunmadı.")
        expect(segments[1].startTime == "00:01:02.000", "Noktalı zaman kodu korunmadı.")
        expect(
            SRTDocument.serialize(segments)
                == "1\n00:00:01,250 --> 00:00:03,500\nİlk satır\nikinci satır\n\n2\n00:01:02.000 --> 00:01:04.125\nSonraki segment\n",
            "SRT serialize sonucu beklenen içerikle eşleşmedi."
        )
    }

    private static func convertsValidTimecodesDeterministically() {
        guard let minuteTimecode = SRTDocument.seconds(from: "00:01:02,345"),
              let hourTimecode = SRTDocument.seconds(from: "01:02:03.500") else {
            fatalError("Geçerli zaman kodları saniyeye çevrilemedi.")
        }

        expect(abs(minuteTimecode - 62.345) < 0.000_1, "Dakikalı zaman kodu hatalı çevrildi.")
        expect(abs(hourTimecode - 3_723.5) < 0.000_1, "Saatli zaman kodu hatalı çevrildi.")
        expect(SRTDocument.seconds(from: "00:61:00,000") == nil, "Geçersiz dakika kabul edildi.")
        expect(SRTDocument.seconds(from: "geçersiz") == nil, "Geçersiz zaman kodu kabul edildi.")
    }

    private static func serializesTimecodesDeterministically() {
        expect(
            SRTDocument.timecode(from: 62.345) == "00:01:02,345",
            "Saniye değeri SRT zaman koduna hatalı çevrildi."
        )
        expect(
            SRTDocument.timecode(from: 3_723.5) == "01:02:03,500",
            "Saatli SRT zaman kodu hatalı üretildi."
        )
        expect(SRTDocument.timecode(from: -0.001) == nil, "Negatif zaman kodu üretildi.")
        expect(SRTDocument.timecode(from: .infinity) == nil, "Sonsuz zaman kodu üretildi.")
    }

    private static func findsActiveSegmentUsingHalfOpenTimeRange() {
        let segments = SRTDocument.parse("""
        1
        00:00:00,000 --> 00:00:01,000
        Bir

        2
        00:00:01,000 --> 00:00:02,000
        İki
        """)

        expect(SRTDocument.activeSegmentID(at: 0, in: segments) == segments[0].id, "İlk segment başlangıçta aktif değil.")
        expect(SRTDocument.activeSegmentID(at: 0.999, in: segments) == segments[0].id, "İlk segment erken kapandı.")
        expect(SRTDocument.activeSegmentID(at: 1, in: segments) == segments[1].id, "Sınırda ikinci segment seçilmedi.")
        expect(SRTDocument.activeSegmentID(at: 2, in: segments) == nil, "Bitişten sonra segment aktif kaldı.")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fatalError(message)
        }
    }
}
