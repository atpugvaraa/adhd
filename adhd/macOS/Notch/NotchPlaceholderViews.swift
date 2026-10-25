import SwiftUI
import HotSwiftUI

struct NotchShelfView: View {
    @ObservedObject var store: FileShelfStore
    let isDropTargeted: Bool
    @ObserveInjection private var redraw

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if store.items.isEmpty {
                ShelfDropPrompt(isDropTargeted: isDropTargeted)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(store.items) { item in
                            ShelfItemRow(item: item, store: store)
                        }
                    }
                }
                .frame(maxHeight: 94)
            }
        }
        .padding(8)
        .background(.white.opacity(isDropTargeted ? 0.12 : 0.055), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(isDropTargeted ? 0.45 : 0.08), lineWidth: 1)
        }
        .enableInjection()
    }
}

private struct ShelfDropPrompt: View {
    let isDropTargeted: Bool

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        Label(
            isDropTargeted ? "Release to stage files" : "Drop files here to keep them close",
            systemImage: isDropTargeted ? "plus" : "arrow.down.doc"
        )
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(isDropTargeted ? 0.95 : 0.6))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .background(.white.opacity(isDropTargeted ? 0.1 : 0.045), in: RoundedRectangle(cornerRadius: 10))
        .enableInjection()
    }
}

private struct ShelfItemRow: View {
    let item: FileShelfItem
    @ObservedObject var store: FileShelfStore

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.open(item)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: item.symbolName)
                        .frame(width: 17)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(item.displayName)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open \(item.displayName)")

            Button {
                store.remove(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Remove from shelf. The original file stays in place.")
        }
        .padding(.vertical, 3)
        .enableInjection()
    }
}

struct NotchSearchPlaceholder: View {
    @ObserveInjection private var redraw

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchRow("Find an app or open a website", symbol: "globe")
            searchRow("Run a command or find a note", symbol: "terminal")
            searchRow("Clipboard history", symbol: "doc.on.clipboard")
        }
        .enableInjection()
    }

    private func searchRow(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.72))
    }
}

struct NotchNotesPlaceholder: View {
    @ObserveInjection private var redraw

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capture a thought")
                .font(.system(size: 14, weight: .medium))
            Text("Jot it down and get back to what you were doing.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.65))
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.08))
                .frame(height: 42)
                .overlay(alignment: .leading) {
                    Text("A thought for later…")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 12)
                }
        }
        .enableInjection()
    }
}
