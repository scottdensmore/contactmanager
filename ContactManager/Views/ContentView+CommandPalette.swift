//
//  ContentView+CommandPalette.swift
//  ContactManager
//
//  Command palette presentation and action wiring.
//

import AppKit
import SwiftUI

extension ContentView {
    func handlingCommandPalette(_ content: some View) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .commandPaletteRequested)) { _ in
                isShowingCommandPalette = true
            }
            .sheet(isPresented: $isShowingCommandPalette, onDismiss: finishCommandPaletteDismissal) {
                CommandPaletteView(
                    query: $commandPaletteQuery,
                    entries: commandPaletteEntries
                ) { entry in
                    pendingCommandPaletteAction = entry.perform
                    isShowingCommandPalette = false
                    commandPaletteQuery = ""
                }
            }
    }

    var commandPaletteEntries: [CommandPaletteAction] {
        var entries = coreCommandPaletteEntries
        entries.append(contentsOf: navigationCommandPaletteEntries)
        entries.append(contentsOf: selectedContactCommandPaletteEntries)
        return entries
    }

    private var coreCommandPaletteEntries: [CommandPaletteAction] {
        [
            command(
                id: "new-contact",
                title: "New Contact",
                subtitle: "Create a blank contact",
                keywords: ["add", "person"],
                systemImage: "person.badge.plus",
                action: addContact
            ),
            command(
                id: "quick-capture",
                title: "Quick Capture",
                subtitle: "Open the quick-entry window",
                keywords: ["natural language", "capture"],
                systemImage: "bolt.fill"
            ) {
                openWindow(id: "quickCapture")
            },
            command(
                id: "find-contacts",
                title: "Find Contacts",
                subtitle: "Focus the contact search field",
                keywords: ["search"],
                systemImage: "magnifyingglass"
            ) {
                NotificationCenter.default.post(name: .focusSearchRequested, object: nil)
            },
            command(
                id: "find-duplicates",
                title: "Find Duplicates",
                subtitle: "Review likely duplicate contacts",
                keywords: ["merge"],
                systemImage: "person.2.badge.gearshape"
            ) {
                showingDuplicates = true
            },
            command(
                id: "import-contacts",
                title: "Import from Contacts",
                subtitle: "Review contacts from the system Contacts app",
                keywords: ["system", "address book"],
                systemImage: "person.crop.circle.badge.plus",
                action: importSystemContacts
            ),
            command(
                id: "import-vcard",
                title: "Import vCard",
                subtitle: "Review contacts from a .vcf file",
                keywords: ["vcf"],
                systemImage: "square.and.arrow.down"
            ) {
                isImportingVCard = true
            },
            command(
                id: "import-csv",
                title: "Import CSV",
                subtitle: "Review contacts from a CSV file",
                keywords: ["spreadsheet"],
                systemImage: "tablecells"
            ) {
                isImportingCSV = true
            },
            command(
                id: "export-vcard",
                title: "Export vCard",
                subtitle: "Export all contacts as .vcf",
                keywords: ["vcf"],
                systemImage: "square.and.arrow.up"
            ) {
                exportDocument = VCardDocument(text: store.exportVCards(contacts))
                isExportingVCard = true
            },
            command(
                id: "export-backup",
                title: "Export Backup",
                subtitle: "Save a JSON backup",
                keywords: ["archive"],
                systemImage: "externaldrive",
                action: exportBackup
            ),
            command(
                id: "export-encrypted-backup",
                title: "Export Encrypted Backup",
                subtitle: "Save a password-protected backup",
                keywords: ["privacy", "secure", "archive"],
                systemImage: "lock.shield"
            ) {
                isPreparingEncryptedBackup = true
            },
            command(
                id: "restore-backup",
                title: "Restore Backup",
                subtitle: "Review and restore a backup",
                keywords: ["import", "json"],
                systemImage: "arrow.counterclockwise"
            ) {
                isRestoringBackup = true
            },
            command(
                id: "settings",
                title: "Settings",
                subtitle: "Open app preferences",
                keywords: ["preferences"],
                systemImage: "gearshape",
                action: openSettings
            ),
        ]
    }

    private var navigationCommandPaletteEntries: [CommandPaletteAction] {
        var entries: [CommandPaletteAction] = [
            command(
                id: "nav-all-contacts",
                title: "All Contacts",
                subtitle: "Show every contact",
                keywords: ["navigate"],
                systemImage: "person.3"
            ) {
                sidebarSelection = .allContacts
            },
        ]

        entries.append(contentsOf: ContactSmartList.allCases.map { smartList in
            command(
                id: "nav-smart-\(smartList.rawValue)",
                title: smartList.title,
                subtitle: "Open smart list",
                keywords: ["navigate", "filter"],
                systemImage: smartList.systemImage
            ) {
                sidebarSelection = .smartList(smartList)
            }
        })

        entries.append(contentsOf: savedSmartLists.map { savedList in
            command(
                id: "nav-saved-smart-\(savedList.persistentModelID.storedString ?? savedList.displayName)",
                title: savedList.displayName,
                subtitle: "Open saved smart list",
                keywords: ["navigate", "filter", savedList.query],
                systemImage: "line.3.horizontal.decrease.circle"
            ) {
                sidebarSelection = .savedSmartList(savedList.persistentModelID)
            }
        })

        entries.append(contentsOf: groups.map { group in
            command(
                id: "nav-group-\(group.persistentModelID.storedString ?? group.displayName)",
                title: group.displayName,
                subtitle: "Open group",
                keywords: ["navigate", "group"],
                systemImage: "folder"
            ) {
                sidebarSelection = .group(group.persistentModelID)
            }
        })

        return entries
    }

    private var selectedContactCommandPaletteEntries: [CommandPaletteAction] {
        guard selectedContact != nil || !selectedContactIDs.isEmpty else { return [] }
        var entries = [
            command(
                id: "selected-export-vcard",
                title: "Export Selected vCard",
                subtitle: "Export selected contacts as .vcf",
                keywords: ["batch", "vcf"],
                systemImage: "square.and.arrow.up",
                action: exportSelectedContactsAsVCard
            ),
            command(
                id: "selected-delete",
                title: "Delete Selected Contacts",
                subtitle: "Delete the current selection",
                keywords: ["remove", "batch"],
                systemImage: "trash",
                isDestructive: true,
                action: requestDeleteSelectedContacts
            ),
        ]

        if let selectedContact {
            entries.insert(
                command(
                    id: "selected-mark-contacted",
                    title: "Mark Contacted Today",
                    subtitle: selectedContact.fullName,
                    keywords: ["history", "follow up"],
                    systemImage: "checkmark.circle"
                ) {
                    markContacted(selectedContact)
                },
                at: 0
            )
            entries.append(
                command(
                    id: "selected-export-pdf",
                    title: "Export Selected as PDF",
                    subtitle: selectedContact.fullName,
                    keywords: ["print"],
                    systemImage: "doc.richtext",
                    action: exportSelectedContactAsPDF
                )
            )
        }

        return entries
    }

    private func command(
        id: String,
        title: String,
        subtitle: String,
        keywords: [String] = [],
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> CommandPaletteAction {
        CommandPaletteAction(
            item: CommandPaletteItem(
                id: id,
                title: title,
                subtitle: subtitle,
                keywords: keywords,
                systemImage: systemImage,
                isDestructive: isDestructive
            ),
            perform: action
        )
    }

    private func finishCommandPaletteDismissal() {
        let action = pendingCommandPaletteAction
        pendingCommandPaletteAction = nil
        clearCommandPalette()
        action?()
    }

    private func clearCommandPalette() {
        commandPaletteQuery = ""
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
