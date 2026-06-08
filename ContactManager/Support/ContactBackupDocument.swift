//
//  ContactBackupDocument.swift
//  ContactManager
//
//  FileDocument wrapper for ContactManager JSON backups.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContactBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var backup: ContactBackup

    init(backup: ContactBackup = ContactBackup()) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        backup = try Self.decode(data)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        let data = try Self.encode(backup)
        return FileWrapper(regularFileWithContents: data)
    }

    static func encode(_ backup: ContactBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> ContactBackup {
        let decoder = JSONDecoder()
        return try decoder.decode(ContactBackup.self, from: data)
    }
}
