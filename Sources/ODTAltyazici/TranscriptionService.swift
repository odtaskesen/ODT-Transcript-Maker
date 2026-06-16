import Foundation

struct OutputSelection {
    let srt: Bool
    let txt: Bool
}

struct TranscriptionResult {
    let outputFiles: [URL]
    let outputFolder: URL
}

final class TranscriptionService: @unchecked Sendable {
    private let fileManager = FileManager.default

    func transcribe(
        inputFile: URL,
        outputs: OutputSelection,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
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

        onProgress("Video sesi hazırlanıyor...")
        let wavFile = paths.tempFolder.appending(path: UUID().uuidString + ".wav")
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

        onProgress("Whisper large-v3-turbo modeli çalışıyor...")
        let destinationBase = inputFile.deletingPathExtension()
        let outputPrefix = paths.tempFolder.appending(path: UUID().uuidString)

        var whisperArguments = [
            "-m", paths.model.path(percentEncoded: false),
            "-f", wavFile.path(percentEncoded: false),
            "-l", "tr",
            "-ng",
            "-of", outputPrefix.path(percentEncoded: false)
        ]

        if outputs.srt {
            whisperArguments.append("-osrt")
        }

        if outputs.txt {
            whisperArguments.append("-otxt")
        }

        try await runProcess(executable: paths.whisper, arguments: whisperArguments)

        onProgress("Çıktılar kaydediliyor...")
        var outputFiles: [URL] = []

        if outputs.srt {
            let generated = outputPrefix.appendingPathExtension("srt")
            let destination = destinationBase.appendingPathExtension("srt")
            try replaceItemIfNeeded(from: generated, to: destination)
            outputFiles.append(destination)
        }

        if outputs.txt {
            let generated = outputPrefix.appendingPathExtension("txt")
            let destination = destinationBase.appendingPathExtension("txt")
            try replaceItemIfNeeded(from: generated, to: destination)
            outputFiles.append(destination)
        }

        try? fileManager.removeItem(at: wavFile)

        return TranscriptionResult(outputFiles: outputFiles, outputFolder: inputFile.deletingLastPathComponent())
    }

    private func replaceItemIfNeeded(from source: URL, to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.moveItem(at: source, to: destination)
    }

    private func runProcess(executable: URL, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? "Bilinmeyen hata"
                    continuation.resume(throwing: AppError.processFailed(output))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
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

    var errorDescription: String? {
        switch self {
        case .missingTool(let message), .missingModel(let message), .componentsMissing(let message):
            return message
        case .processFailed(let output):
            return "İşlem başarısız oldu:\n\(output)"
        }
    }
}
