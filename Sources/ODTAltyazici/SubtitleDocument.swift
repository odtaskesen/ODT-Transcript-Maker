import Foundation

struct SubtitleSegment: Identifiable {
    let id = UUID()
    var index: Int
    var startTime: String
    var endTime: String
    var text: String
}

struct PlayerSeekRequest: Equatable {
    let id = UUID()
    let seconds: TimeInterval
}

enum SRTDocument {
    static func parse(_ raw: String) -> [SubtitleSegment] {
        guard !raw.isEmpty else {
            return []
        }

        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        var result: [SubtitleSegment] = []

        for block in normalized.components(separatedBy: "\n\n") {
            let lines = block
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            guard lines.count >= 2 else { continue }

            var lineIndex = 0
            var cueNumber = result.count + 1
            if let parsed = Int(lines[0].trimmingCharacters(in: .whitespaces)) {
                cueNumber = parsed
                lineIndex = 1
            }

            guard lineIndex < lines.count,
                  let match = lines[lineIndex].firstMatch(
                    of: /(\d{2,}:\d{2}:\d{2}[,.]\d{3})\s*-->\s*(\d{2,}:\d{2}:\d{2}[,.]\d{3})/
                  ) else {
                continue
            }

            let textLines = lines[(lineIndex + 1)...]
            let text = textLines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")

            guard !text.isEmpty else { continue }

            result.append(SubtitleSegment(
                index: cueNumber,
                startTime: String(match.1),
                endTime: String(match.2),
                text: text
            ))
        }

        return result
    }

    static func serialize(_ segments: [SubtitleSegment]) -> String {
        guard !segments.isEmpty else {
            return ""
        }

        return segments.enumerated().map { offset, segment in
            "\(offset + 1)\n\(segment.startTime) --> \(segment.endTime)\n\(segment.text)"
        }.joined(separator: "\n\n") + "\n"
    }

    static func seconds(from timecode: String) -> TimeInterval? {
        let normalized = timecode.replacingOccurrences(of: ",", with: ".")
        let parts = normalized.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]),
              hours >= 0,
              minutes >= 0,
              minutes < 60,
              seconds >= 0,
              seconds < 60 else {
            return nil
        }

        return hours * 3_600 + minutes * 60 + seconds
    }

    static func timecode(from seconds: TimeInterval) -> String? {
        guard seconds.isFinite, seconds >= 0 else {
            return nil
        }

        let totalMilliseconds = Int((seconds * 1_000).rounded())
        let hours = totalMilliseconds / 3_600_000
        let minutes = (totalMilliseconds % 3_600_000) / 60_000
        let wholeSeconds = (totalMilliseconds % 60_000) / 1_000
        let milliseconds = totalMilliseconds % 1_000

        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, wholeSeconds, milliseconds)
    }

    static func activeSegmentID(at seconds: TimeInterval, in segments: [SubtitleSegment]) -> UUID? {
        segments.first { segment in
            guard let start = self.seconds(from: segment.startTime),
                  let end = self.seconds(from: segment.endTime) else {
                return false
            }

            return seconds >= start && seconds < end
        }?.id
    }

    static func displayTime(_ raw: String) -> String {
        let main = raw.split(separator: ",").first.map(String.init)
            ?? raw.split(separator: ".").first.map(String.init)
            ?? raw
        let parts = main.split(separator: ":").map(String.init)

        guard parts.count == 3 else {
            return raw
        }

        let hours = Int(parts[0]) ?? 0
        if hours > 0 {
            return "\(hours):\(parts[1]):\(parts[2])"
        }

        let minutes = Int(parts[1]) ?? 0
        return "\(minutes):\(parts[2])"
    }
}
