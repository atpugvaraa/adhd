import SwiftUI
import HotSwiftUI

struct NotchSearchBar: View {
    @Binding private var query: String
    @FocusState.Binding private var isFocused: Bool
    let onSubmit: () -> Void
    @ObserveInjection private var redraw

    init(
        query: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        onSubmit: @escaping () -> Void
    ) {
        self._query = query
        self._isFocused = isFocused
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.58))

            TextField("Search or capture a thought", text: $query)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .foregroundStyle(.white)
                .font(.system(size: 14))
                .onSubmit(onSubmit)

            if !query.isEmpty {
                Button {
                    query = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: NotchLayoutMetrics.searchBarHeight)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
        .enableInjection()
    }
}
