//
//  ContactWindowView.swift
//  ContactManager
//
//  The single-contact detached window — opened via the row context menu
//  ("Open in New Window"). The window receives the contact's encoded
//  `PersistentIdentifier` (same string scheme used by App Intents and
//  the default-group preference) and resolves it to a live `Contact`
//  out of the shared model container.
//
//  Edits flow through the same `ContactStore` the main window uses, so
//  changes appear in both places and join the main app's undo stack.
//

import SwiftData
import SwiftUI

struct ContactWindowView: View {
    /// JSON-encoded `PersistentIdentifier`. Optional only because
    /// `WindowGroup`'s binding hands us `String?` — an empty value is
    /// treated the same as a missing contact below.
    let encodedID: String?

    @Query(sort: [SortDescriptor(\Contact.lastName), SortDescriptor(\Contact.firstName)])
    private var contacts: [Contact]

    @Environment(\.dismiss) private var dismiss
    /// Whether this window ever showed its contact. Lets us tell "deleted
    /// while open" (auto-close) from "never resolved" — a stale id at launch /
    /// window restoration — where we keep the explanatory unavailable view.
    @State private var hadContact = false

    private var contact: Contact? {
        guard let encodedID,
              let id = PersistentIdentifier.decode(stored: encodedID)
        else { return nil }
        return contacts.first { $0.persistentModelID == id }
    }

    var body: some View {
        Group {
            if let contact {
                ContactDetailView(contact: contact)
                    .navigationTitle(contact.fullName)
                    .onAppear { hadContact = true }
            } else {
                ContentUnavailableView(
                    "Contact Not Found",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text(
                        "This window's contact may have been deleted. " +
                            "Close the window or open another contact from the main window."
                    )
                )
                // If we'd previously shown the contact, it was just deleted —
                // close the now-orphaned window instead of stranding it.
                .onAppear { if hadContact { dismiss() } }
            }
        }
        .frame(minWidth: 460, minHeight: 520)
    }
}
