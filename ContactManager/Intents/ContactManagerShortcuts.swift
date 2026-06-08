//
//  ContactManagerShortcuts.swift
//  ContactManager
//
//  App Shortcuts surfaced in the Shortcuts app and Siri suggestions.
//

import AppIntents

struct ContactManagerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickCaptureContactIntent(),
            phrases: [
                "Quick capture a contact in \(.applicationName)",
                "Add a quick contact to \(.applicationName)",
            ],
            shortTitle: "Quick Capture",
            systemImageName: "text.badge.plus"
        )

        AppShortcut(
            intent: CreateContactIntent(),
            phrases: [
                "Create a contact in \(.applicationName)",
                "Add a contact to \(.applicationName)",
            ],
            shortTitle: "Create Contact",
            systemImageName: "person.crop.circle.badge.plus"
        )

        AppShortcut(
            intent: FindContactIntent(),
            phrases: [
                "Find a contact in \(.applicationName)",
                "Search contacts in \(.applicationName)",
            ],
            shortTitle: "Find Contact",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: AddContactHistoryNoteIntent(),
            phrases: [
                "Add a contact history note in \(.applicationName)",
                "Log contact history in \(.applicationName)",
            ],
            shortTitle: "Add History Note",
            systemImageName: "note.text.badge.plus"
        )
    }
}
