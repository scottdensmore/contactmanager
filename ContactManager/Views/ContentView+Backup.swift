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

    func exportEncryptedBackup(password: String) -> Bool {
        do {
            let backup = ContactBackup.make(contacts: contacts, groups: groups)
            let data = try EncryptedContactBackupDocument.encode(backup, password: password)
            encryptedBackupDocument = EncryptedContactBackupDocument(data: data)
            isPreparingEncryptedBackup = false
            isExportingEncryptedBackup = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restoreBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            if EncryptedContactBackupDocument.isEncrypted(data) {
                pendingEncryptedBackupData = data
                isUnlockingEncryptedBackup = true
                return
            }
            let backup = try ContactBackupDocument.decode(data)
            reviewBackup(backup)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unlockEncryptedBackup(password: String) -> Bool {
        guard let data = pendingEncryptedBackupData else {
            errorMessage = "Choose an encrypted backup before unlocking."
            return false
        }

        do {
            let backup = try EncryptedContactBackupDocument.decode(data, password: password)
            pendingEncryptedBackupData = nil
            isUnlockingEncryptedBackup = false
            reviewBackup(backup)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
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

    func clearPendingEncryptedBackup() {
        pendingEncryptedBackupData = nil
        isUnlockingEncryptedBackup = false
    }

    private func reviewBackup(_ backup: ContactBackup) {
        pendingRestoreBackup = backup
        restorePreview = ContactBackupPreview(backup: backup)
        isReviewingRestore = true
    }
}
