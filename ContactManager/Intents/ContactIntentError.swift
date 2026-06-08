//
//  ContactIntentError.swift
//  ContactManager
//
//  User-facing errors thrown by App Intent mutations.
//

import Foundation

enum ContactIntentError: LocalizedError {
    case blankContactInput
    case blankHistorySummary
    case missingContainer
    case missingContact

    var errorDescription: String? {
        switch self {
        case .blankContactInput: "Enter at least one contact detail."
        case .blankHistorySummary: "Enter a history note."
        case .missingContainer: "ContactManager is not ready yet. Open the app and try again."
        case .missingContact: "That contact could not be found."
        }
    }
}
