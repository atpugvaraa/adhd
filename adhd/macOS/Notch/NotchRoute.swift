// The small set of surfaces that can appear inside the notch.
enum NotchRoute: String, CaseIterable, Identifiable {
    case home
    case search
    case shelf
    case notes

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .search: "Search"
        case .shelf: "File Shelf"
        case .notes: "Thoughts"
        }
    }

    var symbol: String {
        switch self {
        case .home: "sparkle"
        case .search: "magnifyingglass"
        case .shelf: "tray.full"
        case .notes: "note.text"
        }
    }
}
