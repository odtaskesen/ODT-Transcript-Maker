import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AVFoundation
import UserNotifications

struct ContentView: View {
    @State private var selectedFile: URL?
    @State private var selectedFileInfo: MediaFileInfo?
    @State private var createSRT = true
    @State private var createTXT = true
    @State private var status: TranscriptionStatus = .idle
    @State private var logText = "Videoyu buraya sürükleyin veya seçin."
    @State private var isRunning = false
    @State private var isDropTargeted = false
    @State private var componentStatus: ComponentStatus?
    @State private var lastResult: TranscriptionResult?

    private let service = TranscriptionService()
    private let installer = ComponentInstaller()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            dropZone

            outputOptions

            if componentStatus?.isReady != true {
                componentsPanel
            }

            primaryAction

            statusPanel
        }
        .padding(30)
        .frame(minWidth: 760, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            refreshComponentStatus()
            requestNotificationPermission()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ODT Altyazıcı")
                    .font(.system(size: 34, weight: .semibold))

                Text("Türkçe videolar için sade altyazı üretimi.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("large-v3-turbo")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var dropZone: some View {
        Button {
            chooseFile()
        } label: {
            dropZoneContent
            .frame(maxWidth: .infinity, minHeight: 190)
            .padding(18)
            .background(dropZoneBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private var dropZoneContent: some View {
        VStack(spacing: 16) {
            dropZoneIcon
            dropZoneText

            if selectedFile != nil {
                Text("Aynı klasöre kaydedilecek")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dropZoneIcon: some View {
        Image(systemName: selectedFile == nil ? "video.badge.plus" : "checkmark.circle.fill")
            .font(.system(size: 44, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(selectedFile == nil ? Color.secondary : Color.green)
    }

    private var dropZoneText: some View {
        VStack(spacing: 6) {
            Text(selectedFile == nil ? "Videoyu buraya sürükle veya seç" : selectedFileName)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(fileDetailText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    private var outputOptions: some View {
        HStack(spacing: 18) {
            Text("Çıktı")
                .font(.headline)

            Toggle(".srt", isOn: $createSRT)
            Toggle(".txt", isOn: $createTXT)

            Spacer()

            Text("Dil: Türkçe")
                .foregroundStyle(.secondary)
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, 2)
    }

    private var componentsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Label("Kurulum Gerekli", systemImage: "wrench.and.screwdriver")
                    .font(.headline)

                Spacer()

                Button {
                    Task {
                        await prepareComponents()
                    }
                } label: {
                    Label("Gerekli Bileşenleri Hazırla", systemImage: "arrow.down.circle")
                }
                .disabled(isRunning)
            }

            Text("Uygulamanın altyazı üretebilmesi için gerekli dosyalar hazırlanacak.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var primaryAction: some View {
        Button {
            Task {
                await startTranscription()
            }
        } label: {
            HStack {
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "captions.bubble.fill")
                }

                Text(isRunning ? "Altyazı oluşturuluyor" : "Altyazı Oluştur")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!canStart)
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(status.title, systemImage: status.iconName)
                    .font(.headline)

                Spacer()

                if status == .done {
                    Button {
                        openOutputFolder()
                    } label: {
                        Label("Finder'da Göster", systemImage: "folder")
                    }

                    Button {
                        resetSelection()
                    } label: {
                        Label("Yeni Dosya Seç", systemImage: "plus")
                    }
                }
            }

            Text(logText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var dropZoneBackground: some ShapeStyle {
        if isDropTargeted {
            return AnyShapeStyle(Color.accentColor.opacity(0.12))
        }

        return AnyShapeStyle(Color(nsColor: .textBackgroundColor))
    }

    private var selectedFileName: String {
        selectedFile?.lastPathComponent ?? ""
    }

    private var fileDetailText: String {
        guard let selectedFile else {
            return "MP4, MOV, MP3 veya WAV dosyası seçebilirsiniz."
        }

        let details = selectedFileInfo?.displayText ?? "Dosya bilgisi hazırlanıyor..."
        return "\(details)\n\(selectedFile.deletingLastPathComponent().path(percentEncoded: false))"
    }

    private var canStart: Bool {
        selectedFile != nil && (createSRT || createTXT) && !isRunning && componentStatus?.isReady == true
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .audio, .mpeg4Movie, .quickTimeMovie, .mp3, .wav]

        if panel.runModal() == .OK, let url = panel.url {
            selectFile(url)
        }
    }

    private func selectFile(_ url: URL) {
        selectedFile = url
        selectedFileInfo = MediaFileInfo(size: MediaFileInfo.formatSize(url), duration: nil)
        lastResult = nil
        status = .ready
        logText = componentStatus?.isReady == true ? "Hazır. Altyazı oluşturabilirsiniz." : "Gerekli dosyalar eksik. Hazırla butonuna basın."

        Task {
            let info = await MediaFileInfo.load(url: url)
            await MainActor.run {
                if selectedFile == url {
                    selectedFileInfo = info
                }
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }

            Task { @MainActor in
                selectFile(url)
            }
        }

        return true
    }

    @MainActor
    private func startTranscription() async {
        guard let selectedFile else { return }

        isRunning = true
        status = .running
        logText = "Ses hazırlanıyor..."

        do {
            let outputs = OutputSelection(srt: createSRT, txt: createTXT)
            let result = try await service.transcribe(inputFile: selectedFile, outputs: outputs) { message in
                Task { @MainActor in
                    logText = simplifiedProgress(message)
                }
            }

            lastResult = result
            status = .done
            logText = "Tamamlandı. Dosyalar videonun bulunduğu klasöre kaydedildi."
            showCompletionNotification()
        } catch {
            status = .failed
            logText = friendlyError(for: error)
        }

        isRunning = false
    }

    @MainActor
    private func prepareComponents() async {
        isRunning = true
        status = .running
        logText = "Gerekli dosyalar hazırlanıyor..."

        do {
            let newStatus = try await installer.prepare { message in
                Task { @MainActor in
                    logText = message
                }
            }

            componentStatus = newStatus
            status = selectedFile == nil ? .idle : .ready
            logText = selectedFile == nil ? "Videoyu buraya sürükleyin veya seçin." : "Hazır. Altyazı oluşturabilirsiniz."
        } catch {
            refreshComponentStatus()
            status = .failed
            logText = friendlyError(for: error)
        }

        isRunning = false
    }

    @MainActor
    private func refreshComponentStatus() {
        do {
            componentStatus = try installer.status()
            if componentStatus?.isReady == true && selectedFile == nil {
                logText = "Videoyu buraya sürükleyin veya seçin."
            }
        } catch {
            componentStatus = nil
            logText = friendlyError(for: error)
        }
    }

    private func resetSelection() {
        selectedFile = nil
        selectedFileInfo = nil
        lastResult = nil
        status = .idle
        logText = "Videoyu buraya sürükleyin veya seçin."
    }

    private func openOutputFolder() {
        guard let folder = lastResult?.outputFolder ?? selectedFile?.deletingLastPathComponent() else {
            return
        }

        NSWorkspace.shared.open(folder)
    }

    private func simplifiedProgress(_ message: String) -> String {
        if message.localizedCaseInsensitiveContains("Video sesi") {
            return "Ses hazırlanıyor..."
        }

        if message.localizedCaseInsensitiveContains("Whisper") {
            return "Altyazı oluşturuluyor..."
        }

        if message.localizedCaseInsensitiveContains("kaydediliyor") {
            return "Dosyalar kaydediliyor..."
        }

        return message
    }

    private func friendlyError(for error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("bulunamadı") || message.localizedCaseInsensitiveContains("Eksik") {
            return "Gerekli dosyalar eksik. Hazırla butonuna basın."
        }

        return "İşlem tamamlanamadı. Dosyayı kontrol edip tekrar deneyin."
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func showCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "ODT Altyazıcı"
        content.body = "Altyazı dosyaları hazır."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

struct MediaFileInfo {
    let size: String
    let duration: String?

    static func load(url: URL) async -> MediaFileInfo {
        let asset = AVURLAsset(url: url)
        let loadedDuration = try? await asset.load(.duration)
        let seconds = loadedDuration.map(CMTimeGetSeconds) ?? 0

        return MediaFileInfo(
            size: formatSize(url),
            duration: seconds.isFinite && seconds > 0 ? formatDuration(seconds) : nil
        )
    }

    var displayText: String {
        if let duration {
            return "\(duration) • \(size)"
        }

        return size
    }

    private static func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }

    static func formatSize(_ url: URL) -> String {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize else {
            return "Boyut okunamadı"
        }

        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}

enum TranscriptionStatus: Equatable {
    case idle
    case ready
    case running
    case done
    case failed

    var title: String {
        switch self {
        case .idle: "Hazır"
        case .ready: "Hazır"
        case .running: "Çalışıyor"
        case .done: "Tamamlandı"
        case .failed: "Dikkat Gerekiyor"
        }
    }

    var iconName: String {
        switch self {
        case .idle: "checkmark.circle"
        case .ready: "checkmark.circle"
        case .running: "gearshape.2"
        case .done: "checkmark.seal"
        case .failed: "exclamationmark.triangle"
        }
    }
}
