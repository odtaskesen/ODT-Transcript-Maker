import AVFoundation
import AppKit
import Combine
import SwiftUI

@MainActor
final class VideoPlayerController: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false

    private var currentURL: URL?
    private var loadID = UUID()
    private var timeObserver: Any?
    private var isScrubbing = false
    private(set) var playbackRate: Float = 1

    init() {
        player.volume = 1
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.receivePlaybackTime(time)
            }
        }
    }

    func load(url: URL?) {
        guard currentURL != url else { return }

        currentURL = url
        loadID = UUID()
        player.pause()
        isPlaying = false
        currentTime = 0
        duration = 0

        guard let url else {
            player.replaceCurrentItem(with: nil)
            isLoading = false
            return
        }

        isLoading = true
        let asset = AVURLAsset(url: url)
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        let requestedLoadID = loadID

        Task { @MainActor [weak self] in
            let loadedDuration = try? await asset.load(.duration)
            guard let self, self.loadID == requestedLoadID else { return }

            let seconds = loadedDuration.map(CMTimeGetSeconds) ?? 0
            duration = seconds.isFinite && seconds > 0 ? seconds : 0
            isLoading = false
        }
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard player.currentItem != nil else { return }

        if duration > 0, currentTime >= duration - 0.05 {
            seek(to: 0)
        }

        player.playImmediately(atRate: playbackRate)
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to seconds: TimeInterval) {
        let positive = max(0, seconds)
        let bounded = duration > 0 ? min(positive, duration) : positive
        currentTime = bounded
        player.seek(
            to: CMTime(seconds: bounded, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func beginScrubbing() {
        isScrubbing = true
    }

    func scrub(to seconds: TimeInterval) {
        currentTime = seconds
    }

    func endScrubbing() {
        isScrubbing = false
        seek(to: currentTime)
    }

    func setVolume(_ volume: Float) {
        player.volume = min(max(0, volume), 1)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        player.defaultRate = rate
        if isPlaying {
            player.rate = rate
        }
    }

    private func receivePlaybackTime(_ time: CMTime) {
        guard !isScrubbing else { return }

        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite else { return }
        currentTime = seconds

        if duration > 0, seconds >= duration - 0.05, isPlaying {
            isPlaying = false
        }
    }
}

struct VideoPlayerPanel: View {
    let mediaURL: URL?
    let hasVideo: Bool
    let segments: [SubtitleSegment]
    @Binding var selectedSegmentID: UUID?
    let seekRequest: PlayerSeekRequest?

    @StateObject private var controller = VideoPlayerController()
    @State private var volume: Double = 1
    @State private var playbackRate: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Video")
                    .font(.title2.weight(.semibold))

                Text(mediaURL?.lastPathComponent ?? "Düzenlenecek videoyu seçin")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            playerArea

            if playableURL != nil {
                timeline
                playbackControls
                segmentControls
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color(nsColor: .underPageBackgroundColor))
        .task(id: playableURL) {
            controller.load(url: playableURL)
        }
        .onChange(of: seekRequest) { _, request in
            guard let request else { return }
            controller.seek(to: request.seconds)
        }
        .onChange(of: controller.currentTime) { _, currentTime in
            let activeID = SRTDocument.activeSegmentID(at: currentTime, in: segments)
            if selectedSegmentID != activeID {
                selectedSegmentID = activeID
            }
        }
    }

    private var playableURL: URL? {
        hasVideo ? mediaURL : nil
    }

    @ViewBuilder
    private var playerArea: some View {
        ZStack {
            Color.black

            if let playableURL {
                PlayerSurface(player: controller.player)
                    .id(playableURL)

                if controller.isLoading {
                    ProgressView("Video hazırlanıyor...")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: mediaURL == nil ? "play.rectangle" : "waveform")
                        .font(.system(size: 34))

                    Text(mediaURL == nil ? "Video seçildiğinde burada açılır." : "Bu dosya yalnızca ses içeriyor.")
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white.opacity(0.72))
                .padding()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var timeline: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { controller.currentTime },
                    set: { controller.scrub(to: $0) }
                ),
                in: 0...max(controller.duration, 0.01),
                onEditingChanged: { editing in
                    if editing {
                        controller.beginScrubbing()
                    } else {
                        controller.endScrubbing()
                    }
                }
            )

            HStack {
                Text(Self.formatTime(controller.currentTime))
                Spacer()
                Text(Self.formatTime(controller.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button {
                controller.togglePlayback()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 18)
            }
            .keyboardShortcut(.space, modifiers: [])
            .help(controller.isPlaying ? "Durdur (Boşluk)" : "Oynat (Boşluk)")

            Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .foregroundStyle(.secondary)

            Slider(value: $volume, in: 0...1)
                .frame(minWidth: 70, maxWidth: 120)
                .onChange(of: volume) { _, newValue in
                    controller.setVolume(Float(newValue))
                }

            Spacer(minLength: 8)

            Picker("Hız", selection: $playbackRate) {
                ForEach([0.5, 0.75, 1, 1.25, 1.5, 2], id: \.self) { rate in
                    Text(Self.formatRate(rate)).tag(rate)
                }
            }
            .labelsHidden()
            .frame(width: 82)
            .onChange(of: playbackRate) { _, newValue in
                controller.setPlaybackRate(Float(newValue))
            }
        }
        .buttonStyle(.bordered)
    }

    private var segmentControls: some View {
        HStack(spacing: 10) {
            Button {
                moveSegment(by: -1)
            } label: {
                Label("Önceki", systemImage: "backward.end.fill")
            }
            .keyboardShortcut(.leftArrow, modifiers: [.option])
            .disabled(previousSegmentIndex == nil)
            .help("Önceki segment (⌥←)")

            Button {
                moveSegment(by: 1)
            } label: {
                Label("Sonraki", systemImage: "forward.end.fill")
            }
            .keyboardShortcut(.rightArrow, modifiers: [.option])
            .disabled(nextSegmentIndex == nil)
            .help("Sonraki segment (⌥→)")

            Spacer()

            Text(selectedSegmentLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.bordered)
    }

    private var selectedIndex: Int? {
        if let selectedSegmentID,
           let index = segments.firstIndex(where: { $0.id == selectedSegmentID }) {
            return index
        }

        return nil
    }

    private var previousSegmentIndex: Int? {
        guard !segments.isEmpty else { return nil }
        if let selectedIndex {
            return selectedIndex > 0 ? selectedIndex - 1 : nil
        }

        return segments.lastIndex { segment in
            guard let start = SRTDocument.seconds(from: segment.startTime) else { return false }
            return start < controller.currentTime - 0.001
        }
    }

    private var nextSegmentIndex: Int? {
        guard !segments.isEmpty else { return nil }
        if let selectedIndex {
            let next = selectedIndex + 1
            return next < segments.count ? next : nil
        }

        return segments.firstIndex { segment in
            guard let start = SRTDocument.seconds(from: segment.startTime) else { return false }
            return start >= controller.currentTime - 0.001
        }
    }

    private var selectedSegmentLabel: String {
        guard let selectedIndex else {
            return segments.isEmpty ? "SRT segmenti yok" : "Segment seçilmedi"
        }

        return "\(selectedIndex + 1) / \(segments.count)"
    }

    private func moveSegment(by offset: Int) {
        let targetIndex = offset < 0 ? previousSegmentIndex : nextSegmentIndex
        guard let targetIndex else { return }
        selectSegment(at: targetIndex)
    }

    private func selectSegment(at index: Int) {
        let segment = segments[index]
        guard let seconds = SRTDocument.seconds(from: segment.startTime) else { return }
        selectedSegmentID = segment.id
        controller.seek(to: seconds)
    }

    private static func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let remainder = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }

        return String(format: "%d:%02d", minutes, remainder)
    }

    private static func formatRate(_ rate: Double) -> String {
        rate == rate.rounded() ? "\(Int(rate))×" : "\(rate.formatted())×"
    }
}

private struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerLayerView, context: Context) {
        nsView.playerLayer.player = player
    }
}

private final class PlayerLayerView: NSView {
    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override func makeBackingLayer() -> CALayer {
        let playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.black.cgColor
        return playerLayer
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
}
