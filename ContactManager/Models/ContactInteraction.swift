//
//  ContactInteraction.swift
//  ContactManager
//
//  Relationship-history entries attached to a contact.
//

import Foundation
import SwiftData

enum ContactInteractionKind: String, Codable, CaseIterable, Identifiable {
    case note
    case call
    case email
    case meeting
    case message
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .note: "Note"
        case .call: "Call"
        case .email: "Email"
        case .meeting: "Meeting"
        case .message: "Message"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .note: "note.text"
        case .call: "phone"
        case .email: "envelope"
        case .meeting: "person.2"
        case .message: "message"
        case .other: "ellipsis.circle"
        }
    }
}

@Model
final class ContactInteraction {
    var date: Date = Date.now
    var kind: ContactInteractionKind = ContactInteractionKind.note
    var summary: String = ""
    var contact: Contact?

    init(
        kind: ContactInteractionKind = .note,
        summary: String = "",
        date: Date = .now
    ) {
        self.kind = kind
        self.summary = summary
        self.date = date
    }
}
