import Foundation

struct ComponentStatus {
    let ffmpegReady: Bool
    let whisperReady: Bool
    let modelReady: Bool

    var isReady: Bool {
        ffmpegReady && whisperReady && modelReady
    }

    var summary: String {
        if isReady {
            return "Tüm gerekli bileşenler hazır."
        }

        var missing: [String] = []
        if !ffmpegReady { missing.append("ffmpeg") }
        if !whisperReady { missing.append("whisper-cli") }
        if !modelReady { missing.append("large-v3-turbo modeli") }

        return "Eksik bileşenler: " + missing.joined(separator: ", ")
    }
}

final class ComponentInstaller: NSObject, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let modelDownloadURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!
    private let whisperRuntimeFiles = [
        "libwhisper.1.dylib",
        "libwhisper.1.8.7.dylib",
        "libwhisper.dylib",
        "libggml.0.dylib",
        "libggml.0.15.1.dylib",
        "libggml.dylib",
        "libggml-base.0.dylib",
        "libggml-base.0.15.1.dylib",
        "libggml-base.dylib",
        "libggml-cpu.0.dylib",
        "libggml-cpu.0.15.1.dylib",
        "libggml-cpu.dylib",
        "libggml-blas.0.dylib",
        "libggml-blas.0.15.1.dylib",
        "libggml-blas.dylib",
        "libggml-metal.0.dylib",
        "libggml-metal.0.15.1.dylib",
        "libggml-metal.dylib"
    ]

    private var progressHandler: (@Sendable (String) -> Void)?
    private var downloadContinuation: CheckedContinuation<URL, Error>?
    private var pendingDownloadDestination: URL?

    func status() throws -> ComponentStatus {
        let paths = try ComponentPaths.load()
        return ComponentStatus(
            ffmpegReady: fileManager.isExecutableFile(atPath: paths.ffmpeg.path(percentEncoded: false)) || bundledToolURL(named: "ffmpeg") != nil,
            whisperReady: fileManager.isExecutableFile(atPath: paths.whisper.path(percentEncoded: false)) || bundledToolURL(named: "whisper-cli") != nil,
            modelReady: fileManager.fileExists(atPath: paths.model.path(percentEncoded: false))
        )
    }

    func prepare(onProgress: @escaping @Sendable (String) -> Void) async throws -> ComponentStatus {
        progressHandler = onProgress

        let paths = try ComponentPaths.load()
        onProgress("Uygulama klasörleri hazırlanıyor...")
        try fileManager.createDirectory(at: paths.toolsFolder, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.modelsFolder, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.tempFolder, withIntermediateDirectories: true)

        try copyBundledToolIfAvailable(name: "ffmpeg", destination: paths.ffmpeg, onProgress: onProgress)
        try copyBundledToolIfAvailable(name: "whisper-cli", destination: paths.whisper, onProgress: onProgress)
        try copyBundledWhisperRuntime(to: paths.toolsFolder, onProgress: onProgress)

        if !fileManager.fileExists(atPath: paths.model.path(percentEncoded: false)) {
            if let bundledModel = bundledModelURL() {
                onProgress("Paket içindeki large-v3-turbo modeli kopyalanıyor...")
                try fileManager.copyItem(at: bundledModel, to: paths.model)
            } else {
                onProgress("large-v3-turbo modeli indiriliyor. Bu dosya yaklaşık 1.62 GB...")
                try await downloadModel(to: paths.model)
            }
        }

        let currentStatus = try status()
        if !currentStatus.isReady {
            throw AppError.componentsMissing(currentStatus.summary)
        }

        onProgress("Hazırlık tamamlandı.")
        return currentStatus
    }

    private func copyBundledToolIfAvailable(
        name: String,
        destination: URL,
        onProgress: @escaping @Sendable (String) -> Void
    ) throws {
        guard let source = bundledToolURL(named: name) else {
            return
        }

        onProgress("\(name) uygulama klasörüne kopyalanıyor...")
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.copyItem(at: source, to: destination)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path(percentEncoded: false))
    }

    private func copyBundledWhisperRuntime(
        to toolsFolder: URL,
        onProgress: @escaping @Sendable (String) -> Void
    ) throws {
        for fileName in whisperRuntimeFiles {
            guard let source = bundledToolURL(named: fileName) else {
                continue
            }

            let destination = toolsFolder.appending(path: fileName)
            if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
                continue
            }

            onProgress("Whisper çalışma dosyaları kopyalanıyor...")
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    private func downloadModel(to destination: URL) async throws {
        let temporaryDestination = destination.deletingLastPathComponent().appending(path: destination.lastPathComponent + ".download")

        if fileManager.fileExists(atPath: temporaryDestination.path(percentEncoded: false)) {
            try fileManager.removeItem(at: temporaryDestination)
        }

        pendingDownloadDestination = temporaryDestination
        let downloadedFile = try await withCheckedThrowingContinuation { continuation in
            downloadContinuation = continuation
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            session.downloadTask(with: modelDownloadURL).resume()
            session.finishTasksAndInvalidate()
        }

        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.moveItem(at: downloadedFile, to: destination)
    }

    private func bundledToolURL(named name: String) -> URL? {
        bundledResourceURL(name: name, extension: nil, subdirectory: "Tools")
    }

    private func bundledModelURL() -> URL? {
        bundledResourceURL(name: "ggml-large-v3-turbo", extension: "bin", subdirectory: "Models")
    }

    private func bundledResourceURL(name: String, extension ext: String?, subdirectory: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
        ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
    }
}

extension ComponentInstaller: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            guard let pendingDownloadDestination else {
                throw AppError.processFailed("Model indirildi ama kaydedilecek klasör bulunamadı.")
            }

            if fileManager.fileExists(atPath: pendingDownloadDestination.path(percentEncoded: false)) {
                try fileManager.removeItem(at: pendingDownloadDestination)
            }

            try fileManager.moveItem(at: location, to: pendingDownloadDestination)
            downloadContinuation?.resume(returning: pendingDownloadDestination)
        } catch {
            downloadContinuation?.resume(throwing: error)
        }

        pendingDownloadDestination = nil
        downloadContinuation = nil
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error, downloadContinuation != nil {
            downloadContinuation?.resume(throwing: error)
            downloadContinuation = nil
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else {
            progressHandler?("Model indiriliyor...")
            return
        }

        let percent = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100
        progressHandler?(String(format: "Model indiriliyor... %.0f%%", percent))
    }
}

struct ComponentPaths {
    let supportFolder: URL
    let toolsFolder: URL
    let modelsFolder: URL
    let tempFolder: URL
    let ffmpeg: URL
    let whisper: URL
    let model: URL

    static func load() throws -> ComponentPaths {
        let supportFolder = try AppFolders.ensureApplicationSupport()
        let toolsFolder = supportFolder.appending(path: "Tools", directoryHint: .isDirectory)
        let modelsFolder = supportFolder.appending(path: "Models", directoryHint: .isDirectory)
        let tempFolder = supportFolder.appending(path: "Temp", directoryHint: .isDirectory)

        return ComponentPaths(
            supportFolder: supportFolder,
            toolsFolder: toolsFolder,
            modelsFolder: modelsFolder,
            tempFolder: tempFolder,
            ffmpeg: toolsFolder.appending(path: "ffmpeg"),
            whisper: toolsFolder.appending(path: "whisper-cli"),
            model: modelsFolder.appending(path: "ggml-large-v3-turbo.bin")
        )
    }
}
