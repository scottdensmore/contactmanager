//
//  ContentView+FileDialogs.swift
//  ContactManager
//
//  File import/export dialogs and single-contact PDF/print commands.
//

import SwiftUI
import UniformTypeIdentifiers

extension ContentView {
    /// The sheets, importers, exporters, and the error alert.
    func handlingFileDialogs(_ content: some View) -> some View {
        let dialogContent = content
            .sheet(isPresented: $showingDuplicates) {
                DuplicatesView()
            }
            .fileImporter(isPresented: $isImportingVCard, allowedContentTypes: [.vCard]) { result in
                handleImport(result)
            }
            .fileImporter(isPresented: $isImportingCSV, allowedContentTypes: [.commaSeparatedText]) { result in
                handleCSVImport(result)
            }
            .fileImporter(isPresented: $isRestoringBackup, allowedContentTypes: [.json]) { result in
                restoreBackup(result)
            }
        return handlingImportAlerts(handlingReviewSheets(handlingExporters(dialogContent)))
    }

    func handlingExporters(_ content: some View) -> some View {
        content
            .fileExporter(
                isPresented: $isExportingVCard,
                document: exportDocument,
                contentType: .vCard,
                defaultFilename: "Contacts"
            ) { result in
                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
            .fileExporter(
                isPresented: $isExportingBackup,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "ContactManager Backup"
            ) { result in
                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
            .fileExporter(
                isPresented: $isExportingEncryptedBackup,
                document: encryptedBackupDocument,
                contentType: .json,
                defaultFilename: "ContactManager Encrypted Backup"
            ) { result in
                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
            .fileExporter(
                isPresented: $isExportingPDF,
                document: pdfDocument,
                contentType: .pdf,
                defaultFilename: pdfFilename
            ) { result in
                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
    }

    func handlingReviewSheets(_ content: some View) -> some View {
        content
            .sheet(isPresented: $isReviewingImport) {
                ImportReviewView(items: $importReviewItems) { items in
                    Task { await applyImportReview(items) }
                }
            }
            .sheet(isPresented: $isPreparingEncryptedBackup) {
                BackupPasswordPromptView(mode: .export) { password in
                    exportEncryptedBackup(password: password)
                }
            }
            .sheet(isPresented: $isUnlockingEncryptedBackup, onDismiss: clearPendingEncryptedBackup) {
                BackupPasswordPromptView(mode: .unlock) { password in
                    unlockEncryptedBackup(password: password)
                }
            }
            .sheet(isPresented: $isReviewingRestore, onDismiss: clearPendingRestore) {
                if let preview = restorePreview {
                    RestoreBackupPreviewView(preview: preview) {
                        confirmRestoreBackup()
                    }
                }
            }
    }

    func exportSelectedContactAsPDF() {
        guard let contact = selectedContact else {
            errorMessage = "Select a contact to export as PDF."
            return
        }
        guard let data = ContactPDF.data(for: contact) else {
            errorMessage = "Couldn't generate a PDF for that contact."
            return
        }
        pdfDocument = PDFExportDocument(data: data)
        pdfFilename = ContactPDF.filename(for: contact)
        isExportingPDF = true
    }

    func exportSelectedContactsAsVCard() {
        let selected = selectedContacts
        guard !selected.isEmpty else {
            errorMessage = "Select one or more contacts to export."
            return
        }
        exportDocument = VCardDocument(text: store.exportVCards(selected))
        isExportingVCard = true
    }

    func printSelectedContact() {
        guard let contact = selectedContact else {
            errorMessage = "Select a contact to print."
            return
        }
        if !ContactPDF.print(contact) {
            errorMessage = "Couldn't prepare that contact for printing."
        }
    }
}
