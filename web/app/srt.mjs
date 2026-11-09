// SRT ayrıştırma/üretme ve zaman kodu dönüşümleri. Deterministik, yan etkisiz.

const TIMECODE_RE = /^(\d{2}):([0-5]\d):([0-5]\d)[,.](\d{3})$/;
const CUE_RE = /(\d{2}:[0-5]\d:[0-5]\d[,.]\d{3})\s*-->\s*(\d{2}:[0-5]\d:[0-5]\d[,.]\d{3})/;

export function secondsFromTimecode(text) {
  const match = TIMECODE_RE.exec(text.trim());
  if (!match) return null;
  const [, hh, mm, ss, ms] = match;
  return Number(hh) * 3600 + Number(mm) * 60 + Number(ss) + Number(ms) / 1000;
}

export function timecodeFromSeconds(totalSeconds) {
  if (!Number.isFinite(totalSeconds) || totalSeconds < 0) return null;
  const ms = Math.round(totalSeconds * 1000);
  const hh = Math.floor(ms / 3_600_000);
  const mm = Math.floor((ms % 3_600_000) / 60_000);
  const ss = Math.floor((ms % 60_000) / 1000);
  const msRemainder = ms % 1000;
  const pad = (n, len) => String(n).padStart(len, "0");
  return `${pad(hh, 2)}:${pad(mm, 2)}:${pad(ss, 2)},${pad(msRemainder, 3)}`;
}

export function parseSRT(raw) {
  const blocks = raw.replace(/\r\n/g, "\n").split(/\n\n+/).map((b) => b.trim()).filter(Boolean);
  const segments = [];
  for (const block of blocks) {
    const lines = block.split("\n");
    if (lines.length < 2) continue;
    let lineIndex = 0;
    if (/^\d+$/.test(lines[0].trim())) lineIndex = 1;
    const cueMatch = CUE_RE.exec(lines[lineIndex] || "");
    if (!cueMatch) continue;
    const text = lines.slice(lineIndex + 1).join("\n");
    segments.push({
      id: segments.length,
      startTime: cueMatch[1],
      endTime: cueMatch[2],
      text,
    });
  }
  return segments;
}

export function serializeSRT(segments) {
  return segments
    .map((seg, i) => `${i + 1}\n${seg.startTime} --> ${seg.endTime}\n${seg.text}\n`)
    .join("\n");
}

export function segmentsFromChunks(chunks) {
  return chunks.map((chunk, i) => {
    const [start, end] = chunk.timestamp;
    return {
      id: i,
      startTime: timecodeFromSeconds(start) ?? "00:00:00,000",
      endTime: timecodeFromSeconds(end ?? start) ?? "00:00:00,000",
      text: chunk.text.trim(),
    };
  });
}
