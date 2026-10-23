import SwiftUI

/// Debug-only color layers and settled-bound logging for the notch's layout tree.
extension View {
    @ViewBuilder
    func layoutDebugBackground(_ color: Color, named name: String) -> some View {
#if DEBUG
        background {
            GeometryReader { proxy in
                color.opacity(0.32)
                    .preference(
                        key: NotchLayoutDebugBoundsKey.self,
                        value: [NotchLayoutDebugBounds(
                            name: name,
                            frame: proxy.frame(in: .named("notch-layout"))
                        )]
                    )
            }
            // Disable hit testing on this diagnostic layer only. Applying it after
            // `background` would disable the notch view and its hover tracking.
            .allowsHitTesting(false)
        }
#else
        self
#endif
    }

    @ViewBuilder
    func notchLayoutDiagnostics(isExpanded: Bool) -> some View {
#if DEBUG
        modifier(NotchLayoutDiagnostics(isExpanded: isExpanded))
#else
        self
#endif
    }
}

#if DEBUG
private struct NotchLayoutDebugBounds: Equatable {
    let name: String
    let frame: CGRect
}

private struct NotchLayoutDebugBoundsKey: PreferenceKey {
    static var defaultValue: [NotchLayoutDebugBounds] = []

    static func reduce(
        value: inout [NotchLayoutDebugBounds],
        nextValue: () -> [NotchLayoutDebugBounds]
    ) {
        value.append(contentsOf: nextValue())
    }
}

private struct NotchLayoutDiagnostics: ViewModifier {
    let isExpanded: Bool

    @State private var bounds: [NotchLayoutDebugBounds] = []
    @State private var logTask: Task<Void, Never>?

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: "notch-layout")
            .onPreferenceChange(NotchLayoutDebugBoundsKey.self) { newBounds in
                bounds = newBounds
                scheduleLog()
            }
            .onChange(of: isExpanded) { _, _ in scheduleLog() }
            .onAppear(perform: scheduleLog)
            .onDisappear { logTask?.cancel() }
        .enableInjection()
    }

    private func scheduleLog() {
        logTask?.cancel()
        logTask = Task { @MainActor in
            // Debounce spring layout updates so the log contains settled bounds.
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            let measurements = bounds
                .sorted { $0.name < $1.name }
                .map { item in
                    String(
                        format: "%@: x=%.1f y=%.1f w=%.1f h=%.1f",
                        item.name,
                        item.frame.minX,
                        item.frame.minY,
                        item.frame.width,
                        item.frame.height
                    )
                }
                .joined(separator: " | ")

            PerfLog.debug("notch-layout expanded=\(isExpanded) \(measurements)")
        }
    }
}
#endif
