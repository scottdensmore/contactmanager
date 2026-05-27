//
//  ContactField.swift
//  ContactManager
//
//  A labeled, repeatable value (email or phone) belonging to a contact.
//  Modeled as its own SwiftData entity so a contact can have any number of
//  them, each with its own label.
//

import Foundation
import SwiftData

enum FieldKind: String, Codable, CaseIterable {
    case email
    case phone
}

enum FieldLabel: String, Codable, CaseIterable, Identifiable {
    case home
    case work
    case mobile
    case main
    case other

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

@Model
final class ContactField {
    var kind: FieldKind
    var label: FieldLabel
    var value: String
    /// Preserves the order fields were added within their kind.
    var sortIndex: Int
    var contact: Contact?

    init(
        kind: FieldKind,
        label: FieldLabel = .home,
        value: String = "",
        sortIndex: Int = 0
    ) {
        self.kind = kind
        self.label = label
        self.value = value
        self.sortIndex = sortIndex
    }
}

extension FieldKind {
    /// Sensible default label when adding a new field of this kind.
    var defaultLabel: FieldLabel {
        switch self {
        case .email: .home
        case .phone: .mobile
        }
    }
}
