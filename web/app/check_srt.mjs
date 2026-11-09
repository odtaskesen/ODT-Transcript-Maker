import { parseSRT, serializeSRT, secondsFromTimecode, timecodeFromSeconds, segmentsFromChunks } from "./srt.mjs";

function expect(condition, message) {
  if (!condition) {
    console.error("BAŞARISIZ: " + message);
    process.exitCode = 1;
  }
}

function parsesAndSerializesMultilineSegments() {
  const raw = `1
00:00:01,250 --> 00:00:03,500
İlk satır
ikinci satır

2
00:01:02.000 --> 00:01:04.125
Sonraki segment
`;
  const segments = parseSRT(raw);
  expect(segments.length === 2, "İki segment parse edilmeliydi.");
  expect(segments[0].text === "İlk satır\nikinci satır", "Çok satırlı metin korunmadı.");
  expect(segments[1].startTime === "00:01:02.000", "Noktalı zaman kodu korunmadı.");
  expect(
    serializeSRT(segments) ===
      "1\n00:00:01,250 --> 00:00:03,500\nİlk satır\nikinci satır\n\n2\n00:01:02.000 --> 00:01:04.125\nSonraki segment\n",
    "SRT serialize sonucu beklenen içerikle eşleşmedi."
  );
}

function convertsValidTimecodesDeterministically() {
  const minuteTimecode = secondsFromTimecode("00:01:02,345");
  const hourTimecode = secondsFromTimecode("01:02:03.500");
  expect(minuteTimecode !== null && Math.abs(minuteTimecode - 62.345) < 0.0001, "Dakikalı zaman kodu hatalı çevrildi.");
  expect(hourTimecode !== null && Math.abs(hourTimecode - 3723.5) < 0.0001, "Saatli zaman kodu hatalı çevrildi.");
  expect(secondsFromTimecode("00:61:00,000") === null, "Geçersiz dakika kabul edildi.");
  expect(secondsFromTimecode("geçersiz") === null, "Geçersiz zaman kodu kabul edildi.");
}

function serializesTimecodesDeterministically() {
  expect(timecodeFromSeconds(62.345) === "00:01:02,345", "Saniye değeri SRT zaman koduna hatalı çevrildi.");
  expect(timecodeFromSeconds(3723.5) === "01:02:03,500", "Saatli SRT zaman kodu hatalı üretildi.");
  expect(timecodeFromSeconds(-0.001) === null, "Negatif zaman kodu üretildi.");
  expect(timecodeFromSeconds(Infinity) === null, "Sonsuz zaman kodu üretildi.");
}

function buildsSegmentsFromWhisperChunks() {
  const chunks = [
    { timestamp: [0, 2.26], text: " Merhaba dünya." },
    { timestamp: [2.58, 9.14], text: " İkinci cümle." },
  ];
  const segments = segmentsFromChunks(chunks);
  expect(segments.length === 2, "İki chunk'tan iki segment üretilmeliydi.");
  expect(segments[0].text === "Merhaba dünya.", "Segment metni baştaki boşluktan arındırılmalıydı.");
  expect(segments[0].startTime === "00:00:00,000", "İlk segment başlangıcı hatalı.");
  expect(segments[1].endTime === "00:00:09,140", "İkinci segment bitişi hatalı.");
}

parsesAndSerializesMultilineSegments();
convertsValidTimecodesDeterministically();
serializesTimecodesDeterministically();
buildsSegmentsFromWhisperChunks();

if (process.exitCode === 1) {
  console.error("SRT doğrulamaları başarısız.");
} else {
  console.log("SRT doğrulamaları başarılı.");
}
