//
//  ContactStoreError.swift
//  ContactManager
//
//  User-facing errors thrown by ContactStore mutations.
//

import Foundation

enum ContactStoreError: LocalizedError {
    case blankSavedSmartListQuery
    case nothingToMerge

    var errorDescription: String? {
        switch self {
        case .blankSavedSmartListQuery: "Enter a search before saving it as a smart list."
        case .nothingToMerge: "There were no contacts to merge."
        }
    }
}
