#if os(macOS)
import AppKit
import MediaRemoteAdapter
import Observation

struct NowPlayingItem {
    let title: String
    let artist: String
    let album: String?
    let artwork: NSImage?
    let isPlaying: Bool
    private let duration: TimeInterval?
    private let elapsedAtUpdate: TimeInterval
    private let playbackRate: Double
    private let updatedAt: Date

    func remainingDurationLabel(at date: Date) -> String {
        guard let duration, duration.isFinite, duration > 0 else { return "--:--" }
        let elapsed = elapsedAtUpdate + max(date.timeIntervalSince(updatedAt), 0) * playbackRate
        let remainingSeconds = max(Int(duration - elapsed), 0)
        return String(format: "%d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    init?(trackInfo: TrackInfo?) {
        guard
            let payload = trackInfo?.payload,
            let title = payload.title,
            !title.isEmpty
        else {
            return nil
        }

        self.title = title
        artist = payload.artist ?? "Unknown artist"
        album = payload.album
        artwork = payload.artwork
        isPlaying = payload.isPlaying ?? ((payload.playbackRate ?? 0) > 0)
        duration = payload.durationMicros.map { $0 / 1_000_000 }
        elapsedAtUpdate = payload.currentElapsedTime ?? 0
        playbackRate = payload.playbackRate ?? (isPlaying ? 1 : 0)
        updatedAt = Date()
    }

    func progress(at date: Date) -> Double? {
        guard let duration, duration > 0 else { return nil }
        let elapsed = elapsedAtUpdate + max(date.timeIntervalSince(updatedAt), 0) * playbackRate
        return min(max(elapsed / duration, 0), 1)
    }
}

/// Keeps the active system player in sync with the notch and forwards transport controls.
@MainActor
@Observable
final class NowPlayingStore {
    static let shared = NowPlayingStore()

    private(set) var item: NowPlayingItem?
    private let controller: MediaController

    private init() {
        controller = MediaController()
        controller.onTrackInfoReceived = { [weak self] trackInfo in
            DispatchQueue.main.async {
                guard let self else { return }
                self.item = NowPlayingItem(trackInfo: trackInfo)
            }
        }
        controller.onDecodingError = { error, _ in
            DispatchQueue.main.async {
                PerfLog.warning("Could not read current music information: \(error.localizedDescription)")
            }
        }
        controller.onListenerTerminated = {
            DispatchQueue.main.async {
                PerfLog.warning("The now-playing listener stopped")
            }
        }

        controller.startListening()
        PerfLog.mark("now-playing-listener-started")
    }

    func previousTrack() {
        controller.previousTrack()
    }

    func togglePlayback() {
        controller.togglePlayPause()
    }

    func nextTrack() {
        controller.nextTrack()
    }
}
#endif
