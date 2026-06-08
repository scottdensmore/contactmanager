//
//  ContactInteraction.swift
//  ContactManager
//
//  Relationship-history entries attached to a contact.
//

import AppIntents
import Foundation
import SwiftData

enum ContactInteractionKind: String, AppEnum, Codable, CaseIterable, Identifiable {
    case note
    case call
    case email
    case meeting
    case message
    case other

    var id: String { rawValue }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "History Note Kind")

    static let caseDisplayRepresentations: [ContactInteractionKind: DisplayRepresentation] = [
        .note: "Note",
        .call: "Call",
        .email: "Email",
        .meeting: "Meeting",
        .message: "Message",
        .other: "Other",
    ]

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
