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
        let data = configuration.file.regularFileContents ?? Data()
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
