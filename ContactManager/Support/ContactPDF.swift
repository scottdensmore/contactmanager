//
//  ContactPDF.swift
//  ContactManager
//
//  Renders a contact's printable card (PrintableContactView) to PDF data via
//  ImageRenderer, and prints it through PDFKit. Kept out of the view so the
//  PDF generation can be unit-tested.
//

import PDFKit
import SwiftUI

@MainActor
enum ContactPDF {
    /// PDF bytes for a single contact's card, or `nil` if rendering fails.
    /// The page is sized to the rendered card.
    static func data(for contact: Contact) -> Data? {
        let renderer = ImageRenderer(content: PrintableContactView(contact: contact))
        let pdfData = NSMutableData()
        var result: Data?
        // ImageRenderer.render runs its closure synchronously; we build a
        // one-page PDF context the size of the rendered card.
        renderer.render { size, renderInContext in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
                  let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
            else { return }
            context.beginPDFPage(nil)
            renderInContext(context)
            context.endPDFPage()
            context.closePDF()
            result = pdfData as Data
        }
        return result
    }

    /// A file-system-safe filename stem (no extension) for the contact's PDF.
    static func filename(for contact: Contact) -> String {
        VCardTransfer.suggestedFilename(for: contact.fullName)
    }

    /// Presents the system print sheet for the contact's card.
    static func print(_ contact: Contact) -> Bool {
        guard let data = data(for: contact), let document = PDFDocument(data: data) else {
            return false
        }
        let info = NSPrintInfo.shared
        guard let operation = document.printOperation(
            for: info, scalingMode: .pageScaleToFit, autoRotate: false
        ) else { return false }
        operation.run()
        return true
    }
}
