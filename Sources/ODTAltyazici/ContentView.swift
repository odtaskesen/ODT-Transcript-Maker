import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AVFoundation
import UserNotifications

struct ContentView: View {
    @AppStorage("lastSelectedFolderPath") private var lastSelectedFolderPath = ""
    @AppStorage("showCompletionNotifications") private var showCompletionNotifications = true
    @State private var queue: [QueueItem] = []
    @State private var activeQueueID: UUID?
    @State private var runningItemID: UUID?
    @State private var createSRT = true
    @State private var createTXT = true
    @State private var selectedLanguage: TranscriptionLanguage = .turkish
    @State private var activeEditorTab: EditorTab = .text
    @State private var searchQuery = ""
    @State private var status: TranscriptionStatus = .idle
    @State private var logText = "Videoyu buraya sürükleyin veya seçin."
    @State private var isRunning = false
    @State private var isDropTargeted = false
    @State private var componentStatus: ComponentStatus?
    @State private var transcriptText = ""
    @State private var savedTranscriptText = ""
    @State private var srtText = ""
    @State private var segments: [SubtitleSegment] = []
    @State private var isSRTDirty = false
    @State private var transcriptFile: URL?
    @State private var srtFile: URL?
    @State private var saveMessage = ""
    @State private var processingStartedAt: Date?
    @State private var progressFraction: Double?
    @State private var liveTranscript = ""
    @State private var currentTick = Date()
    @State private var showUnsavedChangesDialog = false
    @State private var overwriteTargets: [String] = []
    @State private var showOverwriteDialog = false
    @State private var selectedSegmentID: UUID?
    @State private var playerSeekRequest: PlayerSeekRequest?

    private let service = TranscriptionService()
    private let installer = ComponentInstaller()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            leftPanel
                .frame(width: 360)

            Divider()

            HSplitView {
                editorPanel
                    .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)

                VideoPlayerPanel(
                    mediaURL: activeItem?.url,
                    hasVideo: activeItem?.mediaInfo?.hasVideo ?? true,
                    segments: segments,
                    selectedSegmentID: $selectedSegmentID,
                    seekRequest: playerSeekRequest,
                    setSelectedSegmentStart: { updateSelectedSegmentStart(at: $0) },
                    setSelectedSegmentEnd: { updateSelectedSegmentEnd(at: $0) }
                )
                .frame(minWidth: 320, idealWidth: 400, maxWidth: 620, maxHeight: .infinity)
            }
            .accessibilityIdentifier("player-workspace-split-view")
        }
        .frame(minWidth: 1_220, minHeight: 720)
        .background(appBackground)
        .task {
            refreshComponentStatus()
            requestNotificationPermission()
        }
        .onReceive(tick) { now in
            if isRunning {
                currentTick = now
            }
        }
        .onChange(of: showCompletionNotifications) { _, enabled in
            if enabled {
                requestNotificationPermission()
            }
        }
        .confirmationDialog(
            "Kaydedilmemiş değişiklikler var",
            isPresented: $showUnsavedChangesDialog,
            titleVisibility: .visible
        ) {
            Button("Kaydet ve Devam Et") {
                saveAllDirtyEdits()
                if !hasUnsavedEdits {
                    performReset()
                }
            }

            Button("Kaydetmeden Devam Et", role: .destructive) {
                performReset()
            }

            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Düzenlediğiniz metin henüz kaydedilmedi. Devam ederseniz değişiklikler kaybolur.")
        }
        .confirmationDialog(
            "Mevcut dosyaların üzerine yazılacak",
            isPresented: $showOverwriteDialog,
            titleVisibility: .visible
        ) {
            Button("Üzerine Yaz", role: .destructive) {
                Task {
                    await startQueueProcessing(force: true)
                }
            }

            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("\(overwriteTargets.joined(separator: ", ")) zaten var. Yeniden oluşturursanız mevcut içerik silinir.")
        }
    }

    private var leftPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                dropZoneSection
                outputOptions

                if componentStatus?.isReady != true {
                    componentsPanel
                }

                primaryAction
                statusPanel

                if let activeItem, activeItem.status == .done {
                    resultSummary(for: activeItem)
                }
            }
            .padding(26)
        }
        .background(sidebarBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "captions.bubble.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                Text("large-v3-turbo")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("ODT Altyazıcı")
                    .font(.system(size: 30, weight: .semibold))

                Text("Video ve ses dosyalarından hızlı altyazı üretimi.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var dropZoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if queue.isEmpty {
                dropZone
            } else {
                addFilesBar
                queueList
            }
        }
    }

    private var dropZone: some View {
        Button {
            presentOpenPanel()
        } label: {
            dropZoneContent
                .frame(maxWidth: .infinity, minHeight: 172)
                .padding(18)
                .background(dropZoneBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private var dropZoneContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 44, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Videoyu buraya sürükle veya seç")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("MP4, MOV, MP3 veya WAV dosyası seçebilirsiniz. Birden fazla dosya seçilebilir.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var addFilesBar: some View {
        Button {
            presentOpenPanel()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.secondary)

                Text("Dosya ekle veya sürükle")
                    .font(.callout.weight(.medium))

                Spacer()

                Text("\(queue.count) dosya")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(dropZoneBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.24), style: StrokeStyle(lineWidth: 1.3, dash: [6, 5]))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private var queueList: some View {
        VStack(spacing: 6) {
            ForEach(queue) { item in
                queueRow(item)
            }
        }
    }

    private func queueRow(_ item: QueueItem) -> some View {
        HStack(spacing: 10) {
            Button {
                switchActiveItem(to: item.id)
            } label: {
                HStack(spacing: 10) {
                    queueStatusIcon(item.status)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.url.lastPathComponent)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                            .foregroundStyle(.primary)

                        Text(item.status == .failed ? (item.errorMessage ?? "Başarısız oldu") : (item.mediaInfo?.displayText ?? "Bilgi hazırlanıyor..."))
                            .font(.caption2)
                            .foregroundStyle(item.status == .failed ? .red : .secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if item.status == .failed {
                Button {
                    retryQueueItem(item.id)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Tekrar dene")
            }

            if item.status != .running {
                Button {
                    removeQueueItem(item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Kuyruktan çıkar")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(item.id == activeQueueID ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func queueStatusIcon(_ status: QueueItemStatus) -> some View {
        Group {
            switch status {
            case .pending:
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.secondary)
            case .running:
                ProgressView()
                    .controlSize(.small)
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var outputOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ayarlar")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Dil")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                languageSelector
            }

            HStack(spacing: 16) {
                Toggle(".srt", isOn: $createSRT)
                Toggle(".txt", isOn: $createTXT)
            }
            .toggleStyle(.checkbox)
            .disabled(isRunning)

            Toggle("Bitince bildirim göster", isOn: $showCompletionNotifications)
                .toggleStyle(.checkbox)
                .disabled(isRunning)

            Text(".txt oluşturmasanız bile metin uygulama içinde düzenlenebilir.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var languageSelector: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(TranscriptionLanguage.allCases) { language in
                Button {
                    selectedLanguage = language
                } label: {
                    Label(language.title, systemImage: language.iconName)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 8)
                        .background(language == selectedLanguage ? Color.accentColor.opacity(0.16) : Color(nsColor: .textBackgroundColor))
                        .foregroundStyle(language == selectedLanguage ? Color.accentColor : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(language == selectedLanguage ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.14), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isRunning)
            }
        }
    }

    private var componentsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Label("İlk Kurulum Gerekli", systemImage: "arrow.down.circle")
                    .font(.headline)

                Spacer()

                Button {
                    Task {
                        await prepareComponents()
                    }
                } label: {
                    Label("Modeli İndir ve Hazırla", systemImage: "arrow.down.circle")
                }
                .disabled(isRunning)
            }

            Text("Altyazı oluşturmak için Whisper large-v3-turbo modeli indirilecek (yaklaşık 1,62 GB). İnternet bağlantısı ve yeterli boş disk alanı gerekir. Bu işlem yalnızca bir kez yapılır.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var primaryAction: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await startQueueProcessing()
                }
            } label: {
                HStack {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "captions.bubble.fill")
                    }

                    Text(startButtonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canStart)

            if isRunning && status == .running {
                Button(role: .destructive) {
                    cancelTranscription()
                } label: {
                    Label("Durdur", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.red)
            }
        }
    }

    private var editorPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            editorToolbar
            editorSearchBar

            ZStack(alignment: .center) {
                editorContent

                if isEditorEmpty {
                    emptyEditorState
                        .allowsHitTesting(false)
                }
            }

            editorFooter
        }
        .padding(26)
    }

    private var editorToolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Altyazı")
                        .font(.title2.weight(.semibold))

                    Text(editorSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Picker("Görünüm", selection: $activeEditorTab) {
                    ForEach(EditorTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .disabled(isViewingRunningItem || (transcriptText.isEmpty && srtText.isEmpty))
            }

            HStack(spacing: 8) {
                Button {
                    saveActiveTab()
                } label: {
                    Label(isActiveTabDirty ? "Kaydet" : "Kaydedildi", systemImage: isActiveTabDirty ? "square.and.arrow.down" : "checkmark.circle")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!isActiveTabDirty)

                Button {
                    copyCurrentEditorText()
                } label: {
                    Label("Kopyala", systemImage: "doc.on.doc")
                }
                .disabled(isEditorEmpty)

                Button {
                    openOutputFolder()
                } label: {
                    Label("Finder", systemImage: "folder")
                }
                .disabled(activeItem == nil)

                Button {
                    requestReset()
                } label: {
                    Label("Yeni", systemImage: "plus")
                }
                .disabled(isRunning || queue.isEmpty)

                Spacer()

                if !saveMessage.isEmpty {
                    Text(saveMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button {
                    sendToChatGPT(.spellingCheck)
                } label: {
                    Label(ChatGPTTranscriptAction.spellingCheck.title, systemImage: ChatGPTTranscriptAction.spellingCheck.systemImage)
                }
                .disabled(transcriptText.isEmpty)

                Menu {
                    ForEach([ChatGPTTranscriptAction.summary, .titleIdeas, .description]) { action in
                        Button {
                            sendToChatGPT(action)
                        } label: {
                            Label(action.title, systemImage: action.systemImage)
                        }
                    }
                } label: {
                    Label("ChatGPT Araçları", systemImage: "sparkles")
                }
                .disabled(transcriptText.isEmpty)
            }
        }
    }

    private var editorSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Metin içinde ara", text: $searchQuery)
                .textFieldStyle(.plain)
                .disabled(isEditorEmpty)

            if !searchQuery.isEmpty {
                Text(searchResultText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var editorContent: some View {
        Group {
            if isViewingRunningItem {
                liveTranscriptView
            } else if activeEditorTab == .text {
                TextEditor(text: $transcriptText)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .disabled(transcriptText.isEmpty)
                    .onChange(of: transcriptText) { _, _ in
                        if isTranscriptDirty {
                            saveMessage = "Kaydedilmedi"
                        }
                    }
            } else {
                srtEditor
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.16), lineWidth: 1)
        )
    }

    private var liveTranscriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(liveTranscript)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)

                    Color.clear
                        .frame(height: 1)
                        .id("liveBottom")
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: liveTranscript) { _, _ in
                proxy.scrollTo("liveBottom", anchor: .bottom)
            }
        }
    }

    private var srtEditor: some View {
        Group {
            if segments.isEmpty {
                ScrollView {
                    Text(srtText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach($segments) { $segment in
                                segmentRow($segment)
                            }
                        }
                        .padding(10)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .onChange(of: selectedSegmentID) { _, segmentID in
                        guard let segmentID else { return }
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo(segmentID, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func segmentRow(_ segment: Binding<SubtitleSegment>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("#\(segment.wrappedValue.index)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)

                Text("\(SRTDocument.displayTime(segment.wrappedValue.startTime)) → \(SRTDocument.displayTime(segment.wrappedValue.endTime))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .frame(width: 104, alignment: .leading)

            TextField("", text: segment.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .onChange(of: segment.wrappedValue.text) { _, _ in
                    isSRTDirty = true
                    saveMessage = "Kaydedilmedi"
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .id(segment.wrappedValue.id)
        .background(
            segment.wrappedValue.id == selectedSegmentID
                ? Color.accentColor.opacity(0.18)
                : Color.secondary.opacity(0.055)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            selectSegment(segment.wrappedValue)
        }
    }

    private var editorFooter: some View {
        HStack(spacing: 12) {
            Label(saveStateText, systemImage: isActiveTabDirty ? "circle.dotted" : "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 14)

            Text(textMetrics)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let srtFile {
                Text(srtFile.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func resultSummary(for item: QueueItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sonuç Özeti", systemImage: "checkmark.seal")
                .font(.headline)

            summaryRow("Dil", item.result?.language.title ?? selectedLanguage.title)
            summaryRow("Süre", item.processingDuration.map(Self.formatDuration) ?? "-")
            summaryRow("Çıktılar", item.result?.outputFiles.map(\.lastPathComponent).joined(separator: ", ") ?? "-")
            summaryRow("Konum", item.result?.outputFolder.path(percentEncoded: false) ?? "-")
        }
        .padding(16)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }

    private var emptyEditorState: some View {
        VStack(spacing: 12) {
            Image(systemName: isViewingRunningItem ? "waveform" : "text.alignleft")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text(isViewingRunningItem ? "Metin geldikçe burada görünecek." : "Altyazı oluşunca burada görünecek.")
                .font(.title3.weight(.semibold))

            Text(isViewingRunningItem ? "Whisper ses dosyasını işliyor..." : "Metni buradan düzenleyebilir, arayabilir, kopyalayabilir veya kaydedebilirsiniz.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(28)
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(status.title, systemImage: status.iconName)
                    .font(.headline)

                Spacer()

                if status == .done || status == .failed {
                    Button {
                        openOutputFolder()
                    } label: {
                        Label("Finder'da Göster", systemImage: "folder")
                    }
                    .disabled(activeItem == nil)

                    Button {
                        requestReset()
                    } label: {
                        Label("Yeni Dosya Seç", systemImage: "plus")
                    }
                }
            }

            if status == .running {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progressFraction)
                        .progressViewStyle(.linear)

                    HStack {
                        Text(progressPercentText)

                        Spacer()

                        Text(progressTimingText)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Text(logText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var appBackground: some ShapeStyle {
        AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebarBackground: some ShapeStyle {
        AnyShapeStyle(Color(nsColor: .underPageBackgroundColor))
    }

    private var panelBackground: some ShapeStyle {
        AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
    }

    private var dropZoneBackground: some ShapeStyle {
        if isDropTargeted {
            return AnyShapeStyle(Color.accentColor.opacity(0.12))
        }

        return AnyShapeStyle(Color(nsColor: .textBackgroundColor))
    }

    private var activeItem: QueueItem? {
        guard let activeQueueID else { return nil }
        return queue.first { $0.id == activeQueueID }
    }

    private var pendingCount: Int {
        queue.filter { $0.status == .pending }.count
    }

    private var isViewingRunningItem: Bool {
        runningItemID != nil && runningItemID == activeQueueID
    }

    private var startButtonTitle: String {
        if isRunning {
            return "Altyazı oluşturuluyor"
        }

        return pendingCount > 1 ? "\(pendingCount) Dosyayı İşle" : "Altyazı Oluştur"
    }

    private var canStart: Bool {
        pendingCount > 0 && (createSRT || createTXT) && !isRunning && componentStatus?.isReady == true
    }

    private var isTranscriptDirty: Bool {
        transcriptText != savedTranscriptText
    }

    private var hasUnsavedEdits: Bool {
        (!transcriptText.isEmpty && isTranscriptDirty) || isSRTDirty
    }

    private var isActiveTabDirty: Bool {
        if activeEditorTab == .text {
            return !transcriptText.isEmpty && isTranscriptDirty
        }

        return isSRTDirty
    }

    private var isEditorEmpty: Bool {
        if isViewingRunningItem {
            return liveTranscript.isEmpty
        }

        if activeEditorTab == .text {
            return transcriptText.isEmpty
        }

        return segments.isEmpty && srtText.isEmpty
    }

    private var searchSourceText: String {
        if isViewingRunningItem {
            return liveTranscript
        }

        if activeEditorTab == .text {
            return transcriptText
        }

        return segments.isEmpty ? srtText : segments.map(\.text).joined(separator: "\n")
    }

    private var editorSubtitle: String {
        if isViewingRunningItem {
            return "Canlı önizleme"
        }

        if activeEditorTab == .srt, let srtFile {
            return srtFile.lastPathComponent
        }

        if activeEditorTab == .text, let transcriptFile {
            return transcriptFile.lastPathComponent
        }

        if activeItem?.status == .done {
            return "Uygulama içi düzenleme hazır"
        }

        return "Whisper çıktısı burada düzenlenebilir olacak"
    }

    private var searchResultText: String {
        let count = searchSourceText.localizedStandardRanges(of: searchQuery).count
        return count == 0 ? "Sonuç yok" : "\(count) sonuç"
    }

    private var saveStateText: String {
        if activeEditorTab == .srt {
            if segments.isEmpty && srtText.isEmpty {
                return "Henüz SRT yok"
            }

            return isSRTDirty ? "Kaydedilmedi" : "Kaydedildi"
        }

        if transcriptText.isEmpty {
            return "Henüz metin yok"
        }

        return isTranscriptDirty ? "Kaydedilmedi" : "Kaydedildi"
    }

    private var textMetrics: String {
        if activeEditorTab == .srt && !segments.isEmpty {
            return "\(segments.count) segment"
        }

        let words = transcriptText
            .split { $0.isWhitespace || $0.isNewline }
            .count

        return "\(words) kelime · \(transcriptText.count) karakter"
    }

    private var progressPercentText: String {
        guard let progressFraction else {
            return "Hazırlanıyor..."
        }

        return "%\(Int((progressFraction * 100).rounded()))"
    }

    private var progressTimingText: String {
        guard let processingStartedAt else {
            return ""
        }

        let elapsed = max(0, currentTick.timeIntervalSince(processingStartedAt))
        var parts = ["\(Self.formatDuration(elapsed)) geçti"]

        if let progressFraction, progressFraction > 0.04, elapsed > 3 {
            let remaining = max(0, elapsed / progressFraction - elapsed)
            parts.append("≈ \(Self.formatDuration(remaining)) kaldı")
        }

        return parts.joined(separator: " · ")
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return "\(Int(interval.rounded())) sn"
        }

        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return "\(minutes) dk \(seconds) sn"
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .audio, .mpeg4Movie, .quickTimeMovie, .mp3, .wav]
        if !lastSelectedFolderPath.isEmpty {
            panel.directoryURL = URL(filePath: lastSelectedFolderPath, directoryHint: .isDirectory)
        }

        if panel.runModal() == .OK {
            appendFilesToQueue(panel.urls)
        }
    }

    private func appendFilesToQueue(_ urls: [URL]) {
        let supported = urls.filter { Self.isSupportedMediaFile($0) }

        guard !supported.isEmpty else {
            logText = "Bu dosya türü desteklenmiyor. Video veya ses dosyası seçin."
            return
        }

        if let firstURL = urls.first {
            lastSelectedFolderPath = firstURL.deletingLastPathComponent().path(percentEncoded: false)
        }

        let wasEmpty = queue.isEmpty
        let newItems = supported.map { QueueItem(url: $0) }
        queue.append(contentsOf: newItems)

        if wasEmpty {
            status = componentStatus?.isReady == true ? .ready : .idle
        }

        let skipped = urls.count - supported.count
        logText = skipped > 0
            ? "\(skipped) dosya desteklenmeyen türde, atlandı."
            : (componentStatus?.isReady == true ? "Hazır. Altyazı oluşturabilirsiniz." : "Gerekli dosyalar eksik. Hazırla butonuna basın.")

        if activeQueueID == nil, let first = newItems.first {
            switchActiveItem(to: first.id)
        }

        for newItem in newItems {
            Task {
                let info = await MediaFileInfo.load(url: newItem.url)
                await MainActor.run {
                    mutateItem(newItem.id) { $0.mediaInfo = info }
                }
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        Task { @MainActor in
            var urls: [URL] = []
            for provider in providers {
                if let url = await loadFileURL(from: provider) {
                    urls.append(url)
                }
            }

            guard !urls.isEmpty else { return }
            appendFilesToQueue(urls)
        }

        return true
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: url)
            }
        }
    }

    private static let extraAllowedExtensions: Set<String> = [
        "mkv", "webm", "ogg", "opus", "m4a", "aac", "flac",
        "aiff", "aif", "wma", "avi", "ts", "m2ts", "mts", "3gp"
    ]

    private static func isSupportedMediaFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if extraAllowedExtensions.contains(ext) {
            return true
        }

        guard let type = UTType(filenameExtension: ext) else {
            return false
        }

        return type.conforms(to: .audiovisualContent)
    }

    private func mutateItem(_ id: UUID, _ mutate: (inout QueueItem) -> Void) {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }
        mutate(&queue[idx])
    }

    private func updateActiveItemFromBuffer() {
        guard let activeQueueID, let idx = queue.firstIndex(where: { $0.id == activeQueueID }) else { return }
        guard queue[idx].status != .running else { return }

        queue[idx].transcriptText = transcriptText
        queue[idx].savedTranscriptText = savedTranscriptText
        queue[idx].srtText = srtText
        queue[idx].segments = segments
        queue[idx].isSRTDirty = isSRTDirty
        queue[idx].transcriptFile = transcriptFile
        queue[idx].srtFile = srtFile
    }

    private func loadBufferFromItem(_ id: UUID?) {
        activeQueueID = id
        selectedSegmentID = nil
        playerSeekRequest = nil

        guard let id, let item = queue.first(where: { $0.id == id }) else {
            transcriptText = ""
            savedTranscriptText = ""
            srtText = ""
            segments = []
            isSRTDirty = false
            transcriptFile = nil
            srtFile = nil
            activeEditorTab = .text
            saveMessage = ""
            searchQuery = ""
            return
        }

        transcriptText = item.transcriptText
        savedTranscriptText = item.savedTranscriptText
        srtText = item.srtText
        segments = item.segments
        isSRTDirty = item.isSRTDirty
        transcriptFile = item.transcriptFile
        srtFile = item.srtFile
        saveMessage = ""
        searchQuery = ""
        activeEditorTab = (transcriptText.isEmpty && !srtText.isEmpty) ? .srt : .text
    }

    private func switchActiveItem(to id: UUID?) {
        guard id != activeQueueID else { return }
        updateActiveItemFromBuffer()
        loadBufferFromItem(id)
    }

    private func removeQueueItem(_ id: UUID) {
        guard let idx = queue.firstIndex(where: { $0.id == id }), queue[idx].status != .running else { return }
        queue.remove(at: idx)

        if activeQueueID == id {
            switchActiveItem(to: queue.first?.id)
        }

        if queue.isEmpty {
            status = .idle
            logText = "Videoyu buraya sürükleyin veya seçin."
        }
    }

    private func retryQueueItem(_ id: UUID) {
        mutateItem(id) { item in
            item.status = .pending
            item.errorMessage = nil
        }
    }

    private func existingOutputTargets(for file: URL) -> [String] {
        let base = file.deletingPathExtension()
        var names: [String] = []

        if createSRT {
            let srt = base.appendingPathExtension("srt")
            if FileManager.default.fileExists(atPath: srt.path(percentEncoded: false)) {
                names.append(srt.lastPathComponent)
            }
        }

        if createTXT {
            let txt = base.appendingPathExtension("txt")
            if FileManager.default.fileExists(atPath: txt.path(percentEncoded: false)) {
                names.append(txt.lastPathComponent)
            }
        }

        return names
    }

    @MainActor
    private func startQueueProcessing(force: Bool = false) async {
        guard !isRunning else { return }

        let pendingURLs = queue.filter { $0.status == .pending }.map(\.url)
        guard !pendingURLs.isEmpty else { return }

        if !force {
            let conflicts = pendingURLs.flatMap { existingOutputTargets(for: $0) }
            if !conflicts.isEmpty {
                overwriteTargets = conflicts
                showOverwriteDialog = true
                return
            }
        }

        isRunning = true
        status = .running
        saveMessage = ""

        var wasCancelled = false

        while let index = queue.firstIndex(where: { $0.status == .pending }) {
            let item = queue[index]

            mutateItem(item.id) { $0.status = .running }
            runningItemID = item.id
            switchActiveItem(to: item.id)

            logText = "Ses hazırlanıyor..."
            processingStartedAt = Date()
            currentTick = Date()
            progressFraction = nil
            liveTranscript = ""

            do {
                let outputs = OutputSelection(srt: createSRT, txt: createTXT)
                let result = try await service.transcribe(
                    inputFile: item.url,
                    outputs: outputs,
                    language: selectedLanguage,
                    mediaDurationSeconds: item.mediaInfo?.durationSeconds
                ) { event in
                    Task { @MainActor in
                        handleTranscriptionEvent(event)
                    }
                }

                let duration = processingStartedAt.map { Date().timeIntervalSince($0) }
                let parsedSegments = SRTDocument.parse(result.srtText)

                mutateItem(item.id) {
                    $0.status = .done
                    $0.result = result
                    $0.transcriptText = result.transcriptText
                    $0.savedTranscriptText = result.transcriptText
                    $0.srtText = result.srtText
                    $0.segments = parsedSegments
                    $0.isSRTDirty = false
                    $0.transcriptFile = result.textFile
                    $0.srtFile = result.srtFile
                    $0.processingDuration = duration
                }

                if activeQueueID == item.id {
                    loadBufferFromItem(item.id)
                    saveMessage = result.transcriptText.isEmpty ? "" : "Metin hazır"
                }

                logText = "\(item.url.lastPathComponent) tamamlandı."
            } catch {
                if case AppError.cancelled = error {
                    mutateItem(item.id) { $0.status = .pending }
                    runningItemID = nil
                    logText = "İptal edildi."
                    wasCancelled = true
                    break
                } else {
                    let message = friendlyError(for: error)
                    mutateItem(item.id) {
                        $0.status = .failed
                        $0.errorMessage = message
                    }
                    logText = "\(item.url.lastPathComponent): \(message)"
                }
            }

            runningItemID = nil
        }

        progressFraction = nil
        liveTranscript = ""
        isRunning = false

        if !wasCancelled {
            let doneCount = queue.filter { $0.status == .done }.count
            let failedCount = queue.filter { $0.status == .failed }.count

            if failedCount == 0 {
                status = .done
                logText = doneCount > 1
                    ? "\(doneCount) dosya tamamlandı. Dosyalar ilgili klasörlere kaydedildi."
                    : "Tamamlandı. Dosyalar videonun bulunduğu klasöre kaydedildi."
            } else if doneCount == 0 {
                status = .failed
                logText = "Hiçbir dosya işlenemedi. Dosyaları kontrol edip tekrar deneyin."
            } else {
                status = .done
                logText = "\(doneCount) dosya tamamlandı, \(failedCount) dosya başarısız oldu."
            }

            showCompletionNotification(
                body: failedCount == 0
                    ? "Altyazı dosyaları hazır."
                    : "\(doneCount) dosya tamamlandı, \(failedCount) dosya başarısız oldu."
            )
        } else {
            status = .ready
        }
    }

    private func handleTranscriptionEvent(_ event: TranscriptionEvent) {
        guard isRunning else { return }

        switch event {
        case .stage(let message):
            logText = message
        case .progress(let fraction):
            progressFraction = fraction
        case .segment(let text, _):
            liveTranscript += liveTranscript.isEmpty ? text : "\n" + text
        }
    }

    private func cancelTranscription() {
        logText = "İptal ediliyor..."
        service.cancel()
    }

    @MainActor
    private func prepareComponents() async {
        isRunning = true
        status = .running
        logText = "İlk kurulum hazırlanıyor..."

        do {
            let newStatus = try await installer.prepare { message in
                Task { @MainActor in
                    logText = message
                }
            }

            componentStatus = newStatus
            status = queue.isEmpty ? .idle : .ready
            logText = queue.isEmpty ? "Kurulum tamamlandı. Videoyu buraya sürükleyin veya seçin." : "Kurulum tamamlandı. Altyazı oluşturabilirsiniz."
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
            if componentStatus?.isReady == true && queue.isEmpty {
                logText = "Videoyu buraya sürükleyin veya seçin."
            }
        } catch {
            componentStatus = nil
            logText = friendlyError(for: error)
        }
    }

    private func requestReset() {
        if hasUnsavedEdits {
            showUnsavedChangesDialog = true
        } else {
            performReset()
        }
    }

    private func performReset() {
        queue = []
        activeQueueID = nil
        runningItemID = nil
        transcriptText = ""
        savedTranscriptText = ""
        srtText = ""
        segments = []
        isSRTDirty = false
        transcriptFile = nil
        srtFile = nil
        saveMessage = ""
        selectedSegmentID = nil
        playerSeekRequest = nil
        searchQuery = ""
        processingStartedAt = nil
        progressFraction = nil
        liveTranscript = ""
        activeEditorTab = .text
        status = .idle
        logText = "Videoyu buraya sürükleyin veya seçin."
    }

    private func openOutputFolder() {
        guard let folder = activeItem?.result?.outputFolder ?? activeItem?.url.deletingLastPathComponent() else {
            return
        }

        NSWorkspace.shared.open(folder)
    }

    private func saveActiveTab() {
        if activeEditorTab == .text {
            saveEditedTranscript()
        } else {
            saveEditedSRT()
        }
    }

    private func selectSegment(_ segment: SubtitleSegment) {
        guard let seconds = SRTDocument.seconds(from: segment.startTime) else { return }
        selectedSegmentID = segment.id
        playerSeekRequest = PlayerSeekRequest(seconds: seconds)
    }

    private func updateSelectedSegmentStart(at seconds: TimeInterval) {
        updateSelectedSegmentBoundary(at: seconds, isStart: true)
    }

    private func updateSelectedSegmentEnd(at seconds: TimeInterval) {
        updateSelectedSegmentBoundary(at: seconds, isStart: false)
    }

    private func updateSelectedSegmentBoundary(at seconds: TimeInterval, isStart: Bool) {
        guard let selectedSegmentID,
              let index = segments.firstIndex(where: { $0.id == selectedSegmentID }),
              let timecode = SRTDocument.timecode(from: seconds),
              let existingStart = SRTDocument.seconds(from: segments[index].startTime),
              let existingEnd = SRTDocument.seconds(from: segments[index].endTime) else {
            return
        }

        if isStart {
            guard seconds < existingEnd else {
                saveMessage = "Başlangıç, bitişten önce olmalı"
                return
            }
            segments[index].startTime = timecode
        } else {
            guard seconds > existingStart else {
                saveMessage = "Bitiş, başlangıçtan sonra olmalı"
                return
            }
            segments[index].endTime = timecode
        }

        isSRTDirty = true
        saveMessage = "Kaydedilmedi"
        updateActiveItemFromBuffer()
    }

    private func saveEditedTranscript() {
        guard let url = activeItem?.url else { return }

        let destination = transcriptFile ?? url.deletingPathExtension().appendingPathExtension("txt")

        do {
            try transcriptText.write(to: destination, atomically: true, encoding: .utf8)
            transcriptFile = destination
            savedTranscriptText = transcriptText
            saveMessage = "Kaydedildi"
            updateActiveItemFromBuffer()
        } catch {
            saveMessage = "Kaydedilemedi"
            logText = "Metin kaydedilemedi. Dosya izinlerini kontrol edin."
        }
    }

    private func saveEditedSRT() {
        guard let url = activeItem?.url, !segments.isEmpty else { return }

        let destination = srtFile ?? url.deletingPathExtension().appendingPathExtension("srt")
        let serialized = SRTDocument.serialize(segments)

        do {
            try serialized.write(to: destination, atomically: true, encoding: .utf8)
            srtFile = destination
            srtText = serialized
            isSRTDirty = false
            saveMessage = "SRT kaydedildi"
            updateActiveItemFromBuffer()
        } catch {
            saveMessage = "Kaydedilemedi"
            logText = "SRT kaydedilemedi. Dosya izinlerini kontrol edin."
        }
    }

    private func saveAllDirtyEdits() {
        if !transcriptText.isEmpty && isTranscriptDirty {
            saveEditedTranscript()
        }

        if isSRTDirty {
            saveEditedSRT()
        }
    }

    private func copyCurrentEditorText() {
        let content: String
        if isViewingRunningItem {
            content = liveTranscript
        } else if activeEditorTab == .text {
            content = transcriptText
        } else {
            content = segments.isEmpty ? srtText : SRTDocument.serialize(segments)
        }

        guard !content.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        saveMessage = activeEditorTab == .srt && !isViewingRunningItem ? "SRT kopyalandı" : "Metin kopyalandı"
    }

    private func sendToChatGPT(_ action: ChatGPTTranscriptAction) {
        let prompt = action.prompt(for: transcriptText)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        saveMessage = action.copiedMessage

        if let url = URL(string: "https://chatgpt.com/") {
            NSWorkspace.shared.open(url)
        }
    }

    private func friendlyError(for error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("bulunamadı") || message.localizedCaseInsensitiveContains("Eksik") {
            return "Gerekli dosyalar eksik. Hazırla butonuna basın."
        }

        return "İşlem tamamlanamadı. Dosyayı kontrol edip tekrar deneyin."
    }

    // UNUserNotificationCenter, .app paketi dışında (ör. swift run) çağrılırsa
    // NSInternalInconsistencyException fırlatır; bundle kimliği yoksa atlanır.
    private var notificationsAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private func requestNotificationPermission() {
        guard showCompletionNotifications, notificationsAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func showCompletionNotification(body: String) {
        guard showCompletionNotifications, notificationsAvailable else { return }

        let content = UNMutableNotificationContent()
        content.title = "ODT Altyazıcı"
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

struct QueueItem: Identifiable {
    let id = UUID()
    let url: URL
    var status: QueueItemStatus = .pending
    var mediaInfo: MediaFileInfo?
    var result: TranscriptionResult?
    var transcriptText: String = ""
    var savedTranscriptText: String = ""
    var srtText: String = ""
    var segments: [SubtitleSegment] = []
    var isSRTDirty: Bool = false
    var transcriptFile: URL?
    var srtFile: URL?
    var errorMessage: String?
    var processingDuration: TimeInterval?
}

enum QueueItemStatus: Equatable {
    case pending
    case running
    case done
    case failed
}

struct MediaFileInfo {
    let size: String
    let duration: String?
    let durationSeconds: Double?
    let hasVideo: Bool

    static func load(url: URL) async -> MediaFileInfo {
        let asset = AVURLAsset(url: url)
        let loadedDuration = try? await asset.load(.duration)
        let videoTracks = try? await asset.loadTracks(withMediaType: .video)
        let seconds = loadedDuration.map(CMTimeGetSeconds) ?? 0
        let hasDuration = seconds.isFinite && seconds > 0

        return MediaFileInfo(
            size: formatSize(url),
            duration: hasDuration ? formatDuration(seconds) : nil,
            durationSeconds: hasDuration ? seconds : nil,
            hasVideo: !(videoTracks?.isEmpty ?? true)
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

enum EditorTab: String, CaseIterable, Identifiable {
    case text
    case srt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: "Metin"
        case .srt: "SRT"
        }
    }
}

private extension String {
    func localizedStandardRanges(of searchText: String) -> [Range<String.Index>] {
        guard !searchText.isEmpty else {
            return []
        }

        var ranges: [Range<String.Index>] = []
        var searchStart = startIndex

        while searchStart < endIndex,
              let range = range(
                of: searchText,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<endIndex,
                locale: .current
              ) {
            ranges.append(range)
            searchStart = range.upperBound
        }

        return ranges
    }
}
