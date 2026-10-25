import CoreGraphics
import SwiftUI

/// Shared dimensions for the notch surface and its content.
enum NotchLayoutMetrics {
    static let compactSize = CGSize(width: 220, height: 38)
    static let compactPlayingWidth: CGFloat = 310
    static let compactContentHorizontalPadding: CGFloat = 13
    static let expandedWidth: CGFloat = 420
    static let expandedPanelWidth: CGFloat = 460
    static let contentPadding: CGFloat = 16

    // Preserve the hand-tuned vertical balance while the debug layers show its bounds.
    static let verticalBalanceAdjustment: CGFloat = -6

    static let sectionSpacing: CGFloat = 12
    static let searchBarHeight: CGFloat = 38
    static let searchResultRowHeight: CGFloat = 40
    static let searchResultsViewportHeight: CGFloat = 168
    static let topCornerRadius: CGFloat = 6
    static let compactBottomRadius: CGFloat = 14
    static let expandedBottomRadius: CGFloat = 24
    
    static let innerCornerRadii: RectangleCornerRadii = RectangleCornerRadii(bottomLeading: 12, bottomTrailing: 12)
}
