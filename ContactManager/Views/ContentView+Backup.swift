//
//  ContentView+Backup.swift
//  ContactManager
//
//  Backup export and additive restore actions.
//

import Foundation

extension ContentView {
    func exportBackup() {
        backupDocument = ContactBackupDocument(backup: ContactBackup.make(contacts: contacts, groups: groups))
        isExportingBackup = true
    }

    func restoreBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            let backup = try ContactBackupDocument.decode(data)
            restoreSummary = try store.restoreBackup(backup)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
