//
//  LayoutMetrics.swift
//  ContactManager
//
//  Shared column-width constants for the three-column NavigationSplitView.
//  Keeping them in one place lets `ContentView` derive the window minimum
//  from the same values the columns use.
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
    /// the window minimum below accounts for it.
    static let detailMinWidth: CGFloat = 360

    /// Window minimum height.
    static let windowMinHeight: CGFloat = 480

    /// Derived window minimum width: sidebar + list + detail.
    static let windowMinWidth: CGFloat = sidebarMinWidth + listMinWidth + detailMinWidth
}
