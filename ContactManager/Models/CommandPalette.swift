//
//  CommandPalette.swift
//  ContactManager
//
//  Pure command-palette filtering helpers.
//

struct CommandPaletteItem: Identifiable, Equatable {
    let id: String
    var title: String
    var subtitle: String
    var keywords: [String] = []
    var systemImage: String = "command"
    var isDestructive = false

    var searchText: String {
        ([title, subtitle] + keywords).joined(separator: " ").lowercased()
    }
}

enum CommandPalette {
    static func filtered(_ items: [CommandPaletteItem], matching query: String) -> [CommandPaletteItem] {
        let tokens = query
            .lowercased()
            .split { $0.isWhitespace || $0 == "," }
            .map(String.init)
        guard !tokens.isEmpty else { return items }
        return items.filter { item in
            tokens.allSatisfy { item.searchText.contains($0) }
        }
    }
}
