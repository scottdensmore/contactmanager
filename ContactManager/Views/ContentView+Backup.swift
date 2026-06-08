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
            pendingRestoreBackup = backup
            restorePreview = ContactBackupPreview(backup: backup)
            isReviewingRestore = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmRestoreBackup() {
        guard let backup = pendingRestoreBackup else {
            errorMessage = "Choose a backup before restoring."
            return
        }

        do {
            restoreSummary = try store.restoreBackup(backup)
            clearPendingRestore()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearPendingRestore() {
        pendingRestoreBackup = nil
        restorePreview = nil
        isReviewingRestore = false
    }
}
