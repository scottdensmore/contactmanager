//
//  ContentView+Import.swift
//  ContactManager
//
//  Import handlers (system Contacts, vCard file picker, vCard URL drops)
//  factored out of `ContentView` so the main view stays focused on
//  composition and state. Each handler runs the parse off the main
//  actor and presents a review step before `ContactStore` writes anything.
//

import Foundation
import SwiftUI

private enum CSVImportOutcome {
    case parsed([ParsedContact])
    case unrecognized
    case unreadable
}

extension ContentView {
    // MARK: - System Contacts import

    func importSystemContacts() {
        Task {
            importProgress = ImportProgress()
            defer { importProgress = nil }
            // Permission prompt + fetch + mapping all run off the main actor;
            // only the final review presentation hops back here.
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
            presentImportReview(parsed)
        }
    }

    @MainActor
    func presentImportReview(_ parsed: [ParsedContact]) {
        importProgress = nil
        importReviewItems = ImportReview.makeItems(for: parsed, existing: contacts)
        isReviewingImport = true
    }

    @MainActor
    func applyImportReview(_ items: [ImportReviewItem]) async {
        importProgress = ImportProgress(done: 0, total: items.count)
        defer { importProgress = nil }
        do {
            for chunk in items.chunked(into: 500) {
                try store.applyImportReview(chunk)
                importProgress?.done += chunk.count
                await Task.yield()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - vCard import

    /// Imports one or more vCard files dropped onto the contact list.
    func importVCardURLs(_ urls: [URL]) {
        Task {
            importProgress = ImportProgress()
            defer { importProgress = nil }
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
            presentImportReview(parsed)
        }
    }

    // MARK: - CSV import

    func handleCSVImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            Task {
                importProgress = ImportProgress()
                defer { importProgress = nil }
                let outcome: CSVImportOutcome = await Task.detached {
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url) else { return .unreadable }
                    // CSV exports are commonly UTF-8 but Excel still emits
                    // UTF-16 with a BOM; try both before giving up.
                    let text: String
                    if let utf8 = String(data: data, encoding: .utf8) {
                        text = utf8
                    } else if let utf16 = String(data: data, encoding: .utf16) {
                        text = utf16
                    } else {
                        return .unreadable
                    }
                    guard let parsed = CSV.parseContacts(text) else { return .unrecognized }
                    return .parsed(parsed)
                }.value

                switch outcome {
                case .unreadable:
                    errorMessage = "That file couldn't be read as a CSV."
                case .unrecognized:
                    errorMessage = "Couldn't recognize the CSV — the header row " +
                        "doesn't include any known contact columns (e.g. First Name, " +
                        "Email, Phone)."
                case .parsed(let contacts) where contacts.isEmpty:
                    errorMessage = "No contacts were found in that file."
                case .parsed(let contacts):
                    presentImportReview(contacts)
                }
            }
        }
    }

    func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            Task {
                importProgress = ImportProgress()
                defer { importProgress = nil }
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
                presentImportReview(parsed)
            }
        }
    }
}
