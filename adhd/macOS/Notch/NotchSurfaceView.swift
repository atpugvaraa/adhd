// SwiftUI owns the notch's content and interaction. AppKit owns the panel.
import AppKit
import SwiftUI
import HotSwiftUI
import UniformTypeIdentifiers

struct NotchSurfaceView: View {
    @State private var route: NotchRoute = .home
    @State private var isExpanded = false
    @State private var collapseTask: Task<Void, Never>?
    @State private var searchQuery = ""
    @State private var isDropTargeted = false
    @FocusState private var searchFieldFocused: Bool
    @ObserveInjection private var redraw
    @StateObject private var shelfStore = FileShelfStore.shared
    @StateObject private var searchModel = UniversalSearchModel()

    var body: some View {
        expandedContent
            .fixedSize(horizontal: false, vertical: true)
            // .layoutDebugBackground(.orange, named: "content natural")
            .frame(
                width: isExpanded ? NotchLayoutMetrics.expandedWidth : NotchLayoutMetrics.compactSize.width,
                height: isExpanded ? nil : NotchLayoutMetrics.compactSize.height,
                alignment: .top
            )
            // .layoutDebugBackground(.blue, named: "content frame")
            .opacity(isExpanded ? 1 : 0)
            .scaleEffect(isExpanded ? 1 : 0.96, anchor: .top)
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
            .onChange(of: searchQuery) { _, query in
                inferRoute(from: query)
            }
            .onDisappear { collapseTask?.cancel() }
            .enableInjection()
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
                    NotchHomeView()
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
                onSubmit: { searchModel.submit(query: searchQuery) }
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
        collapseTask?.cancel()
        collapseTask = nil

        if hovering {
            guard !isExpanded else { return }
            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.82)) {
                isExpanded = true
            }
        } else {
            guard isExpanded else { return }
            collapseTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.82)) {
                    isExpanded = false
                }
            }
        }
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
                ForEach(model.results) { result in
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
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .enableInjection()
    }
}
