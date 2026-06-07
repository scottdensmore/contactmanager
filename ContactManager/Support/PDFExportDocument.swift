//
//  PDFExportDocument.swift
//  ContactManager
//
//  A tiny FileDocument wrapping PDF bytes, used by the "Export as PDF" dialog.
//

import SwiftUI
import UniformTypeIdentifiers

struct PDFExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    static var writableContentTypes: [UTType] { [.pdf] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
