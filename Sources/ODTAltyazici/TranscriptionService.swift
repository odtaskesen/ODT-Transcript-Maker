import Foundation

struct OutputSelection {
    let srt: Bool
    let txt: Bool
}

enum TranscriptionEvent: Sendable {
    case stage(String)
    case progress(Double)
    case segment(text: String, endSeconds: Double)
}

enum TranscriptionLanguage: String, CaseIterable, Identifiable {
    case turkish = "tr"
    case english = "en"
    case german = "de"
    case dutch = "nl"
    case spanish = "es"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .turkish: "Türkçe"
        case .english: "İngilizce"
        case .german: "Almanca"
        case .dutch: "Felemenkçe"
        case .spanish: "İspanyolca"
        }
    }

    var iconName: String {
        switch self {
        case .turkish: "moon.stars"
        case .english: "textformat.abc"
        case .german: "building.columns"
        case .dutch: "wind"
        case .spanish: "sun.max"
        }
    }
}

struct TranscriptionResult {
    let outputFiles: [URL]
    let outputFolder: URL
    let srtFile: URL?
    let srtText: String
    let textFile: URL?
    let transcriptText: String
    let language: TranscriptionLanguage
}

final class TranscriptionService: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let stateLock = NSLock()
    private var currentProcess: Process?
    private var cancelRequested = false

    func cancel() {
        let process = stateLock.withLock {
            cancelRequested = true
            return currentProcess
        }

        process?.terminate()
    }

    func transcribe(
        inputFile: URL,
        outputs: OutputSelection,
        language: TranscriptionLanguage,
        mediaDurationSeconds: Double?,
        onEvent: @escaping @Sendable (TranscriptionEvent) -> Void
    ) async throws -> TranscriptionResult {
        stateLock.withLock {
            cancelRequested = false
        }

        let paths = try ComponentPaths.load()
        try fileManager.createDirectory(at: paths.tempFolder, withIntermediateDirectories: true)

        guard fileManager.isExecutableFile(atPath: paths.ffmpeg.path(percentEncoded: false)) else {
            throw AppError.missingTool(
                "ffmpeg bulunamadı. Önce Gerekli Bileşenleri Hazırla butonunu kullanın."
            )
        }

        guard fileManager.isExecutableFile(atPath: paths.whisper.path(percentEncoded: false)) else {
            throw AppError.missingTool(
                "whisper-cli bulunamadı. Önce Gerekli Bileşenleri Hazırla butonunu kullanın."
            )
        }

        guard fileManager.fileExists(atPath: paths.model.path(percentEncoded: false)) else {
            throw AppError.missingModel(
                "large-v3-turbo modeli bulunamadı. Önce Gerekli Bileşenleri Hazırla butonunu kullanın."
            )
        }

        let wavFile = paths.tempFolder.appending(path: UUID().uuidString + ".wav")
        let outputPrefix = paths.tempFolder.appending(path: UUID().uuidString)

        defer {
            try? fileManager.removeItem(at: wavFile)
            try? fileManager.removeItem(at: outputPrefix.appendingPathExtension("srt"))
            try? fileManager.removeItem(at: outputPrefix.appendingPathExtension("txt"))
        }

        onEvent(.stage("Ses hazırlanıyor..."))
        try await runProcess(
            executable: paths.ffmpeg,
            arguments: [
                "-y",
                "-i", inputFile.path(percentEncoded: false),
                "-ar", "16000",
                "-ac", "1",
                "-c:a", "pcm_s16le",
                wavFile.path(percentEncoded: false)
            ]
        )

        try throwIfCancelled()

        onEvent(.stage("Altyazı oluşturuluyor..."))
        let destinationBase = inputFile.deletingPathExtension()
        let audioDuration = wavDurationSeconds(of: wavFile) ?? mediaDurationSeconds

        var whisperArguments = [
            "-m", paths.model.path(percentEncoded: false),
            "-f", wavFile.path(percentEncoded: false),
            "-l", language.rawValue,
            "-pp",
            "-of", outputPrefix.path(percentEncoded: false)
        ]

        if outputs.srt {
            whisperArguments.append("-osrt")
        }

        whisperArguments.append("-otxt")

        let progress = ProgressAccumulator()
        try await runProcess(executable: paths.whisper, arguments: whisperArguments) { line in
            if let percent = Self.parseProgressPercent(line) {
                if let best = progress.update(Double(percent) / 100) {
                    onEvent(.progress(best))
                }
                return
            }

            if let segment = Self.parseSegmentLine(line) {
                onEvent(.segment(text: segment.text, endSeconds: segment.endSeconds))

                if let audioDuration, audioDuration > 0 {
                    let fraction = min(segment.endSeconds / audioDuration, 0.99)
                    if let best = progress.update(fraction) {
                        onEvent(.progress(best))
                    }
                }
            }
        }

        onEvent(.stage("Çıktılar kaydediliyor..."))
        var outputFiles: [URL] = []
        var srtDestination: URL?
        var srtText = ""

        if outputs.srt {
            let generated = outputPrefix.appendingPathExtension("srt")
            srtText = (try? String(contentsOf: generated, encoding: .utf8)) ?? ""
            let destination = destinationBase.appendingPathExtension("srt")
            try replaceItemIfNeeded(from: generated, to: destination)
            outputFiles.append(destination)
            srtDestination = destination
        }

        let generatedText = outputPrefix.appendingPathExtension("txt")
        let transcriptText = (try? String(contentsOf: generatedText, encoding: .utf8)) ?? ""
        var textDestination: URL?

        if outputs.txt {
            let destination = destinationBase.appendingPathExtension("txt")
            try replaceItemIfNeeded(from: generatedText, to: destination)
            outputFiles.append(destination)
            textDestination = destination
        }

        return TranscriptionResult(
            outputFiles: outputFiles,
            outputFolder: inputFile.deletingLastPathComponent(),
            srtFile: srtDestination,
            srtText: srtText,
            textFile: textDestination,
            transcriptText: transcriptText,
            language: language
        )
    }

    private var isCancelled: Bool {
        stateLock.withLock { cancelRequested }
    }

    private func throwIfCancelled() throws {
        if isCancelled {
            throw AppError.cancelled
        }
    }

    // 16 kHz mono s16 PCM: 32000 bayt/sn. İlerleme tahmini için yeterli hassasiyet.
    private func wavDurationSeconds(of file: URL) -> Double? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: file.path(percentEncoded: false)),
              let size = attributes[.size] as? Int64,
              size > 44 else {
            return nil
        }

        return Double(size - 44) / 32000.0
    }

    private static func parseProgressPercent(_ line: String) -> Int? {
        guard line.contains("progress"),
              let match = line.firstMatch(of: /progress\s*=\s*(\d+)%/) else {
            return nil
        }

        return Int(match.1)
    }

    private struct ParsedSegment {
        let endSeconds: Double
        let text: String
    }

    private static func parseSegmentLine(_ line: String) -> ParsedSegment? {
        guard let match = line.firstMatch(
            of: /^\[\d{2,}:\d{2}:\d{2}[.,]\d{3} --> (\d{2,}):(\d{2}):(\d{2})[.,](\d{3})\]\s*(.*)$/
        ) else {
            return nil
        }

        let hours = Double(match.1) ?? 0
        let minutes = Double(match.2) ?? 0
        let seconds = Double(match.3) ?? 0
        let millis = Double(match.4) ?? 0
        let text = String(match.5).trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else {
            return nil
        }

        return ParsedSegment(
            endSeconds: hours * 3600 + minutes * 60 + seconds + millis / 1000,
            text: text
        )
    }

    private func replaceItemIfNeeded(from source: URL, to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.moveItem(at: source, to: destination)
    }

    private func runProcess(
        executable: URL,
        arguments: [String],
        onLine: (@Sendable (String) -> Void)? = nil
    ) async throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let terminationStream = AsyncStream<Int32> { continuation in
            process.terminationHandler = { finished in
                continuation.yield(finished.terminationStatus)
                continuation.finish()
            }
        }

        try process.run()

        let alreadyCancelled = stateLock.withLock {
            currentProcess = process
            return cancelRequested
        }

        if alreadyCancelled {
            process.terminate()
        }

        // Çıktı akış halinde okunur; aksi halde 64 KB'lik pipe tamponu dolunca
        // alt süreç bloklanır ve uzun videolarda uygulama sonsuza dek bekler.
        let tail = OutputTail()
        do {
            for try await line in pipe.fileHandleForReading.bytes.lines {
                onLine?(line)
                tail.append(line)
            }
        } catch {
            pipe.fileHandleForReading.readabilityHandler = { handle in
                _ = handle.availableData
            }
        }

        var status: Int32 = -1
        for await value in terminationStream {
            status = value
        }

        pipe.fileHandleForReading.readabilityHandler = nil

        let wasCancelled = stateLock.withLock {
            currentProcess = nil
            return cancelRequested
        }

        if wasCancelled {
            throw AppError.cancelled
        }

        guard status == 0 else {
            let output = tail.contents()
            throw AppError.processFailed(output.isEmpty ? "Bilinmeyen hata" : output)
        }
    }
}

private final class ProgressAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var best: Double = 0

    func update(_ value: Double) -> Double? {
        lock.lock()
        defer { lock.unlock() }

        let clamped = min(max(value, 0), 1)
        guard clamped > best else {
            return nil
        }

        best = clamped
        return best
    }
}

private final class OutputTail: @unchecked Sendable {
    private let lock = NSLock()
    private var text = ""

    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }

        text.append(line)
        text.append("\n")
        if text.count > 8192 {
            text = String(text.suffix(4096))
        }
    }

    func contents() -> String {
        lock.lock()
        defer { lock.unlock() }
        return text
    }
}

enum AppFolders {
    static func ensureApplicationSupport() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appending(path: "ODT Altyazıcı", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appending(path: "Tools", directoryHint: .isDirectory), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appending(path: "Models", directoryHint: .isDirectory), withIntermediateDirectories: true)

        return folder
    }
}

enum AppError: LocalizedError {
    case missingTool(String)
    case missingModel(String)
    case componentsMissing(String)
    case processFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingTool(let message), .missingModel(let message), .componentsMissing(let message):
            return message
        case .processFailed(let output):
            return "İşlem başarısız oldu:\n\(output)"
        case .cancelled:
            return "İşlem iptal edildi."
        }
    }
}
