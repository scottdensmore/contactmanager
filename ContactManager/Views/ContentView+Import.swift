//
//  ContentView+Import.swift
//  ContactManager
//
//  Import handlers (system Contacts, vCard file picker, vCard URL drops)
//  factored out of `ContentView` so the main view stays focused on
//  composition and state. Each handler runs the parse off the main
//  actor and routes inserts through `ContactStore` so they participate
//  in the existing Undo group.
//

import Foundation
import SwiftUI

extension ContentView {
    // MARK: - System Contacts import

    func importSystemContacts() {
        Task {
            // Permission prompt + fetch + mapping all run off the main actor;
            // only the final insert hops back here.
            let parsed: [ParsedContact]
            do {
                parsed = try await Task.detached(priority: .userInitiated) {
                    try await ContactsBridge.fetchAllParsed()
                }.value
            } catch {
                errorMessage = error.localizedDescription
                return
            }
            guard !parsed.isEmpty else {
                errorMessage = "No contacts were found in your system Contacts."
                return
            }
            do {
                try store.importContacts(parsed)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - vCard import

    /// Imports one or more vCard files dropped onto the contact list.
    func importVCardURLs(_ urls: [URL]) {
        Task {
            let parsed: [ParsedContact] = await Task.detached {
                var all: [ParsedContact] = []
                for url in urls {
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url),
                          let text = String(data: data, encoding: .utf8)
                    else { continue }
                    all.append(contentsOf: VCard.parse(text))
                }
                return all
            }.value

            guard !parsed.isEmpty else {
                errorMessage = "No contacts were found in that file."
                return
            }
            do {
                try store.importContacts(parsed)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            Task {
                // Read and parse off the main actor so large files don't block UI.
                let parsed: [ParsedContact]? = await Task.detached {
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url),
                          let text = String(data: data, encoding: .utf8) else { return nil }
                    return VCard.parse(text)
                }.value

                guard let parsed else {
                    errorMessage = "That file couldn't be read as a vCard."
                    return
                }
                guard !parsed.isEmpty else {
                    errorMessage = "No contacts were found in that file."
                    return
                }
                do {
                    try store.importContacts(parsed)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
