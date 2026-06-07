//
//  VCardTransfer.swift
//  ContactManager
//
//  A `Transferable` wrapping a single contact's vCard payload + suggested
//  filename. Dragging a row hands one of these to Finder, which receives
//  a `.vcf` file named after the contact.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct VCardTransfer: Transferable {
    /// Encoded `PersistentIdentifier` of the source contact, so an in-app drop
    /// (e.g. onto a sidebar group) can resolve which contact was dragged. Empty
    /// when the identity isn't relevant (e.g. the detail Share button).
    var contactID: String = ""
    /// File-system-safe stem, without the `.vcf` extension. Computed by
    /// `suggestedFilename(for:)` so the sanitization is testable.
    let suggestedName: String
    /// The vCard 3.0 text the file will contain.
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        // Dragging to Finder (or another app) writes a `.vcf` file.
        FileRepresentation(exportedContentType: .vCard) { transfer in
            // Write to a per-drag tempdir so multiple drags don't collide on
            // a shared filename. Finder copies the file out by the time the
            // OS clears the temp dir at next launch.
            let directory = FileManager.default.temporaryDirectory
                .appending(path: "vcard-drag-\(UUID().uuidString)")
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            let url = directory.appending(path: "\(transfer.suggestedName).vcf")
            try Data(transfer.text.utf8).write(to: url)
            return SentTransferredFile(url, allowAccessingOriginalFile: false)
        }
        // Dropping within the app exposes just the contact id as plain text, so
        // a sidebar group can add the dragged contact without parsing a vCard.
        ProxyRepresentation(exporting: \.contactID)
    }

    /// Pure helper: produces a filename stem ("Ada Lovelace") from the
    /// contact's `fullName`, falling back to "Contact" for an unnamed one
    /// and stripping characters that are illegal on macOS file systems.
    static func suggestedFilename(for displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Contact" : trimmed
        // Forward slash and colon are the only path-illegal characters on
        // HFS+/APFS; replace them rather than dropping them so two distinct
        // names don't collapse into one.
        return base
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }
}
