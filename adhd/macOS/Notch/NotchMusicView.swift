#if os(macOS)
import AppKit
import HotSwiftUI
import SwiftUI

struct NotchHomeView: View {
    let artworkNamespace: Namespace.ID
    let isExpanded: Bool
    @State private var nowPlaying = NowPlayingStore.shared
    @ObserveInjection private var redraw

    var body: some View {
        Group {
            if isExpanded, let item = nowPlaying.item, item.isPlaying {
                NotchMusicView(
                    item: item,
                    store: nowPlaying,
                    artworkNamespace: artworkNamespace
                )
            }
        }
        .animation(.snappy(duration: 0.24), value: nowPlaying.item?.title)
        .enableInjection()
    }
}

/// Compact playback activity shown inside the widened notch while it is closed.
struct NotchCompactNowPlayingView: View {
    let item: NowPlayingItem
    let artworkNamespace: Namespace.ID
    @ObserveInjection private var redraw

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 9) {
                artwork

                Spacer(minLength: 8)

                Text(item.remainingDurationLabel(at: context.date))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.78))
                    .matchedGeometryEffect(id: "now-playing-remaining-time", in: artworkNamespace)
                    // .layoutDebugBackground(.yellow, named: "compact remaining-time")
            }
            // .layoutDebugBackground(.orange, named: "compact content before inset")
            .padding(.horizontal, NotchLayoutMetrics.compactContentHorizontalPadding)
            .frame(width: NotchLayoutMetrics.compactPlayingWidth, height: NotchLayoutMetrics.compactSize.height)
            // .layoutDebugBackground(.green, named: "compact player frame")
        }
        .foregroundStyle(.white)
        .enableInjection()
    }

    private var artwork: some View {
        Group {
            if let artwork = item.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.white.opacity(0.12))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                    }
            }
        }
        .frame(width: 25, height: 25)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .matchedGeometryEffect(id: "now-playing-artwork", in: artworkNamespace)
        // .layoutDebugBackground(.pink, named: "compact artwork")
    }
}

private struct NotchMusicView: View {
    let item: NowPlayingItem
    let store: NowPlayingStore
    let artworkNamespace: Namespace.ID
    @ObserveInjection private var redraw

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    artwork

                    VStack(alignment: .leading, spacing: 3) {
                        Label("NOW PLAYING", systemImage: "waveform")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))

                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)

                        Text(item.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    transportControls
                }

                if let progress = item.progress(at: context.date) {
                    HStack(spacing: 8) {
                        ProgressView(value: progress)
                            .tint(.white.opacity(0.72))
                            .frame(height: 2)
                        Text(item.remainingDurationLabel(at: context.date))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.62))
                            .matchedGeometryEffect(id: "now-playing-remaining-time", in: artworkNamespace)
                    }
                }
            }
            .padding(9)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
        .enableInjection()
    }

    private var artwork: some View {
        Group {
            if let artwork = item.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 9)
                    .fill(.white.opacity(0.1))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                    }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .matchedGeometryEffect(id: "now-playing-artwork", in: artworkNamespace)
    }

    private var transportControls: some View {
        HStack(spacing: 5) {
            Button(action: store.previousTrack) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 30)
                    .contentShape(Rectangle())
            }
            .help("Previous track")

            Button(action: store.togglePlayback) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 30)
                    .background(.white, in: Circle())
            }
            .help("Pause")

            Button(action: store.nextTrack) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 30)
                    .contentShape(Rectangle())
            }
            .help("Next track")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.88))
    }
}
#endif
