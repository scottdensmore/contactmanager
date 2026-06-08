//
//  CommandPaletteView.swift
//  ContactManager
//
//  Keyboard-first command launcher.
//

import SwiftUI

struct CommandPaletteAction: Identifiable {
    var item: CommandPaletteItem
    var perform: () -> Void

    var id: String { item.id }
}

struct CommandPaletteView: View {
    @Binding var query: String
    var entries: [CommandPaletteAction]
    var perform: (CommandPaletteAction) -> Void

    @FocusState private var searchFocused: Bool

    private var filteredEntries: [CommandPaletteAction] {
        let filteredIDs = Set(CommandPalette.filtered(entries.map(\.item), matching: query).map(\.id))
        return entries.filter { filteredIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search commands", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(14)
                .focused($searchFocused)
                .onSubmit(runFirstMatch)
                .accessibilityIdentifier("command-palette-search-field")

            Divider()

            List(filteredEntries) { entry in
                Button {
                    perform(entry)
                } label: {
                    CommandPaletteRow(item: entry.item)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("command-palette-row-\(entry.id)")
            }
            .listStyle(.plain)
            .frame(minHeight: 280)
            .overlay {
                if filteredEntries.isEmpty {
                    ContentUnavailableView("No Commands", systemImage: "command")
                }
            }
        }
        .frame(width: 520, height: 420)
        .onAppear {
            searchFocused = true
        }
    }

    private func runFirstMatch() {
        guard let entry = filteredEntries.first else { return }
        perform(entry)
    }
}

private struct CommandPaletteRow: View {
    var item: CommandPaletteItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .frame(width: 24)
                .foregroundStyle(item.isDestructive ? .red : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .foregroundStyle(item.isDestructive ? .red : .primary)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}

#Preview {
    CommandPaletteView(
        query: .constant(""),
        entries: [
            CommandPaletteAction(
                item: CommandPaletteItem(
                    id: "new",
                    title: "New Contact",
                    subtitle: "Create a blank contact",
                    systemImage: "person.badge.plus"
                ),
                perform: {}
            ),
        ],
        perform: { _ in }
    )
}
