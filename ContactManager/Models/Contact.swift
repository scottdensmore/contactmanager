//
//  Contact.swift
//  ContactManager
//
//  The SwiftData model backing a single contact. Replaces the legacy
//  Core Data `Contact` NSManagedObject.
//

import Foundation
import SwiftData

@Model
final class Contact {
    var firstName: String
    var lastName: String
    var emailAddress: String
    var phoneNumber: String
    var createdAt: Date

    init(
        firstName: String = "",
        lastName: String = "",
        emailAddress: String = "",
        phoneNumber: String = "",
        createdAt: Date = .now
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.emailAddress = emailAddress
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
    }
}

extension Contact {
    /// Human-readable name, falling back to a placeholder for brand-new contacts.
    var fullName: String {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? "New Contact" : name
    }

    /// One or two uppercase letters used for the avatar placeholder.
    var initials: String {
        let first = firstName.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? ""
        let last = lastName.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? ""
        let combined = (first + last).uppercased()
        return combined.isEmpty ? "#" : combined
    }

    /// Lowercased key used to sort contacts by last name, then first name.
    var sortKey: String {
        let last = lastName.trimmingCharacters(in: .whitespaces)
        let primary = last.isEmpty ? firstName : last
        return primary.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Lowercased first name, trimmed — used as the secondary sort key so it
    /// stays consistent with `sortKey`.
    var firstNameSortKey: String {
        firstName.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Deterministic, launch-stable seed for the avatar tint. Derived from the
    /// persisted creation date so the color survives relaunches (unlike
    /// `hashValue`, which is per-process) and doesn't shift when the name is
    /// edited.
    var colorSeed: Int {
        Int(truncatingIfNeeded: createdAt.timeIntervalSinceReferenceDate.bitPattern)
    }
}
