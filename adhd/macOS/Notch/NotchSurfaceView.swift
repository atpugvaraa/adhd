// SwiftUI owns the notch's content and interaction. AppKit owns the panel.
import AppKit
import SwiftUI
import HotSwiftUI
import UniformTypeIdentifiers


@MainActor @Observable
final class NotchInteractionModel {
    private(set) var hotKeyRequest = 0
    var onFocusRequested: (() -> Void)?

    func requestFocus() {
        onFocusRequested?()
    }

    func toggleFromHotKey() {
        onFocusRequested?()
        hotKeyRequest += 1
    }
}

struct NotchSurfaceView: View {
    @State var interaction: NotchInteractionModel
    @State private var route: NotchRoute = .home
    @State private var isExpanded = false
    @State private var isHoveringNotch = false
    @State private var isPresentedByHotKey = false
    @State private var collapseTask: Task<Void, Never>?
    @State private var searchQuery = ""
    @State private var isDropTargeted = false
    @FocusState private var searchFieldFocused: Bool
    @Namespace private var nowPlayingArtworkNamespace
    @ObserveInjection private var redraw
    @StateObject private var shelfStore = FileShelfStore.shared
    @StateObject private var searchModel = UniversalSearchModel()
    @State private var nowPlaying = NowPlayingStore.shared

    var body: some View {
        ZStack(alignment: .top) {
            if isExpanded {
                expandedContent
            } else if let item = compactNowPlayingItem {
                NotchCompactNowPlayingView(
                    item: item,
                    artworkNamespace: nowPlayingArtworkNamespace
                )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        // .layoutDebugBackground(.orange, named: "content natural")
        .frame(
            width: surfaceWidth,
            height: isExpanded ? nil : NotchLayoutMetrics.compactSize.height,
            alignment: .top
        )
        // .layoutDebugBackground(.blue, named: "notch surface frame")
        .allowsHitTesting(isExpanded)
        .accessibilityHidden(!isExpanded)
        .background { surface }
        .clipShape(NotchShape(
            topRadius: NotchLayoutMetrics.topCornerRadius,
            bottomRadius: isExpanded
                ? NotchLayoutMetrics.expandedBottomRadius
                : NotchLayoutMetrics.compactBottomRadius
        ))
        .contentShape(Rectangle())
        .onHover(perform: handleHover)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // .layoutDebugBackground(.purple, named: "panel hosted view")
        .notchLayoutDiagnostics(isExpanded: isExpanded)
        .animation(.interactiveSpring(response: 0.38, dampingFraction: 0.82), value: isExpanded)
        .animation(.bouncy, value: nowPlaying.item?.isPlaying)
        .onChange(of: searchQuery) { _, query in
            inferRoute(from: query)
        }
        .onChange(of: interaction.hotKeyRequest) { _, _ in
            handleHotKeyToggle()
        }
        .onChange(of: searchModel.completedActionCount) { _, _ in
            resetAfterSearchAction()
        }
        .onDisappear { collapseTask?.cancel() }
        .enableInjection()
    }

    private var compactNowPlayingItem: NowPlayingItem? {
        guard
            !isExpanded,
            route == .home,
            searchQuery.isEmpty,
            let item = nowPlaying.item,
            item.isPlaying
        else { return nil }
        return item
    }

    private var surfaceWidth: CGFloat {
        guard !isExpanded else { return NotchLayoutMetrics.expandedWidth }
        return compactNowPlayingItem == nil
            ? NotchLayoutMetrics.compactSize.width
            : NotchLayoutMetrics.compactPlayingWidth
    }

    private var surface: some View {
        NotchShape(
            topRadius: NotchLayoutMetrics.topCornerRadius,
            bottomRadius: isExpanded
                ? NotchLayoutMetrics.expandedBottomRadius
                : NotchLayoutMetrics.compactBottomRadius
        )
        .fill(.black)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: NotchLayoutMetrics.sectionSpacing) {
            HStack(spacing: 8) {
                Image(systemName: route.symbol)
                    .foregroundStyle(.secondary)
                Text(isDropTargeted ? NotchRoute.shelf.title : route.title)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("adhd")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }

            Group {
                if isDropTargeted || route == .shelf {
                    NotchShelfView(store: shelfStore, isDropTargeted: isDropTargeted)
                } else if !searchQuery.isEmpty {
                    NotchSearchResultsView(model: searchModel)
                } else {
                    NotchHomeView(
                        artworkNamespace: nowPlayingArtworkNamespace,
                        isExpanded: isExpanded
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                shelfStore.stage(providers)
                route = .shelf
                return true
            }

            NotchSearchBar(
                query: $searchQuery,
                isFocused: $searchFieldFocused,
                onSubmit: { searchModel.submit(query: searchQuery) },
                onMoveSelection: searchModel.moveSelection(by:)
            )
        }
        // .layoutDebugBackground(.red, named: "content stack")
        .clipShape(.rect(cornerRadii: NotchLayoutMetrics.innerCornerRadii))
        .padding(.vertical, NotchLayoutMetrics.verticalBalanceAdjustment)
        .foregroundStyle(.white)
        .padding(NotchLayoutMetrics.contentPadding)
        // .layoutDebugBackground(.green, named: "padded content")
    }

    private func inferRoute(from query: String) {
        searchModel.update(query: query)
        route = query.isEmpty ? .home : .search
    }

    private func handleHover(_ hovering: Bool) {
        isHoveringNotch = hovering
        collapseTask?.cancel()
        collapseTask = nil

        if hovering {
            PerfLog.mark("notch-search-focus-hover")
            interaction.requestFocus()
            searchFieldFocused = true
            expand()
        } else {
            guard !isPresentedByHotKey else { return }
            guard isExpanded else { return }
            collapseTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, !isHoveringNotch, !isPresentedByHotKey else { return }
                collapse()
            }
        }
    }

    private func handleHotKeyToggle() {
        if isPresentedByHotKey {
            PerfLog.mark("notch-search-dismiss-hotkey")
            isPresentedByHotKey = false
            if isHoveringNotch {
                interaction.requestFocus()
                searchFieldFocused = true
                expand()
            } else {
                searchFieldFocused = false
                collapse()
            }
        } else {
            PerfLog.mark("notch-search-focus-hotkey")
            isPresentedByHotKey = true
            interaction.requestFocus()
            searchFieldFocused = true
            expand()
        }
    }

    private func expand() {
        guard !isExpanded else { return }
        withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.82)) {
            isExpanded = true
        }
    }

    private func collapse() {
        withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.82)) {
            isExpanded = false
        }
        searchFieldFocused = false
    }

    private func resetAfterSearchAction() {
        collapseTask?.cancel()
        collapseTask = nil
        isPresentedByHotKey = false
        searchQuery = ""
        route = .home
        searchFieldFocused = false
        collapse()
    }

}

private struct NotchSearchResultsView: View {
    @ObservedObject var model: UniversalSearchModel

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let statusMessage = model.statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            } else if model.results.isEmpty {
                Text("No matches yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(model.results.indices, id: \.self) { index in
                                let result = model.results[index]
                                Button {
                                    model.perform(result)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: result.symbol)
                                            .frame(width: 16)
                                            .foregroundStyle(.white.opacity(0.65))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.title)
                                                .font(.system(size: 12, weight: .medium))
                                                .lineLimit(1)
                                            Text(result.detail)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        Spacer(minLength: 0)
                                        if case .launch(let url) = result.action {
                                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                                .resizable()
                                                .frame(width: 20, height: 20)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .frame(height: NotchLayoutMetrics.searchResultRowHeight)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(index == model.selectedIndex ? .white.opacity(0.12) : .clear)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: min(
                        CGFloat(model.results.count) * NotchLayoutMetrics.searchResultRowHeight,
                        NotchLayoutMetrics.searchResultsViewportHeight
                    ))
                    .onChange(of: model.selectedIndex) { _, selectedIndex in
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(selectedIndex, anchor: .center)
                        }
                    }
                    // .layoutDebugBackground(.yellow, named: "search results viewport")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .enableInjection()
    }
}
