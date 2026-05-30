//
//  LayoutMetrics.swift
//  ContactManager
//
//  Shared column-width constants for the three-/four-column layout. Keeping
//  them in one place lets `ContentView` derive the window's minimum width
//  from the same values the columns use, so tuning a column min can't drift
//  the window min out of sync.
//

import Foundation

enum LayoutMetrics {
    // Sidebar (groups).
    static let sidebarMinWidth: CGFloat = 180
    static let sidebarIdealWidth: CGFloat = 215
    static let sidebarMaxWidth: CGFloat = 320

    // Contact list.
    static let listMinWidth: CGFloat = 240
    static let listIdealWidth: CGFloat = 280
    static let listMaxWidth: CGFloat = 420

    /// Detail column. Doesn't get an explicit column width (it takes the
    /// remaining space), but the form needs at least this much to look right;
    /// the window's minimum accounts for it.
    static let detailMinWidth: CGFloat = 300

    // Inspector.
    static let inspectorMinWidth: CGFloat = 240
    static let inspectorIdealWidth: CGFloat = 300
    static let inspectorMaxWidth: CGFloat = 420

    /// Window minimum height.
    static let windowMinHeight: CGFloat = 480

    /// The window's minimum width for the current layout state.
    static func windowMinWidth(isInspectorVisible: Bool) -> CGFloat {
        let base = sidebarMinWidth + listMinWidth + detailMinWidth
        return base + (isInspectorVisible ? inspectorMinWidth : 0)
    }
}
