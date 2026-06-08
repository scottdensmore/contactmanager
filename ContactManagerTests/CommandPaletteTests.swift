//
//  CommandPaletteTests.swift
//  ContactManagerTests
//
//  Covers the pure filtering logic behind the command palette UI.
//

@testable import ContactManager
import Testing

struct CommandPaletteTests {
    private let items = [
        CommandPaletteItem(
            id: "new",
            title: "New Contact",
            subtitle: "Create a blank contact",
            keywords: ["add", "person"]
        ),
        CommandPaletteItem(
            id: "duplicates",
            title: "Find Duplicates",
            subtitle: "Review likely duplicate contacts",
            keywords: ["merge"]
        ),
        CommandPaletteItem(
            id: "backup",
            title: "Export Backup",
            subtitle: "Save a JSON backup",
            keywords: ["archive", "restore"]
        ),
    ]

    @Test func emptyQueryReturnsAllItemsInOrder() {
        #expect(CommandPalette.filtered(items, matching: "").map(\.id) == [
            "new", "duplicates", "backup",
        ])
    }

    @Test func filteringMatchesTitleSubtitleAndKeywordsCaseInsensitively() {
        #expect(CommandPalette.filtered(items, matching: "person").map(\.id) == ["new"])
        #expect(CommandPalette.filtered(items, matching: "duplicate").map(\.id) == ["duplicates"])
        #expect(CommandPalette.filtered(items, matching: "json").map(\.id) == ["backup"])
        #expect(CommandPalette.filtered(items, matching: "MERGE").map(\.id) == ["duplicates"])
    }

    @Test func filteringRequiresEveryQueryTokenToMatch() {
        #expect(CommandPalette.filtered(items, matching: "find contacts").map(\.id) == ["duplicates"])
        #expect(CommandPalette.filtered(items, matching: "find json").isEmpty)
    }
}
