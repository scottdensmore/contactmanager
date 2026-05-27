//
//  VCardDocument.swift
//  ContactManager
//
//  A tiny FileDocument wrapping vCard text, used by the export file dialog.
//

import SwiftUI
import UniformTypeIdentifiers

struct VCardDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.vCard] }
    static var writableContentTypes: [UTType] { [.vCard] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        // An empty/absent payload is an empty document; only genuinely
        // undecodable bytes are treated as a corrupt file.
        guard let data = configuration.file.regularFileContents else {
            text = ""
            return
        }
        guard let decoded = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = decoded
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
