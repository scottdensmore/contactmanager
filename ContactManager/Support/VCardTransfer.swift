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
    /// File-system-safe stem, without the `.vcf` extension. Computed by
    /// `suggestedFilename(for:)` so the sanitization is testable.
    let suggestedName: String
    /// The vCard 3.0 text the file will contain.
    let text: String

    static var transferRepresentation: some TransferRepresentation {
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
