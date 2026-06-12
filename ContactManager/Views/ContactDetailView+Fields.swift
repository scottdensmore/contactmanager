//
//  ContactDetailView+Fields.swift
//  ContactManager
//
//  Repeatable email/phone editor sections for ContactDetailView.
//

import SwiftUI

extension ContactDetailView {
    // MARK: - Repeatable field sections

    func fieldSection(_ title: String, kind: FieldKind, fields: [ContactField]) -> some View {
        Section(title) {
            if fields.isEmpty {
                emptyDetailHint(
                    "No \(title.lowercased()) saved",
                    systemImage: kind == .email ? "envelope" : "phone"
                )
                .accessibilityIdentifier("contact-empty-\(kind.rawValue)-hint")
            }

            ForEach(fields) { field in
                ContactFieldRow(field: field, focusedFieldID: $focusedFieldID)
            }
            .onDelete { offsets in
                delete(offsets, from: fields)
            }

            Button {
                addField(kind: kind)
            } label: {
                Label("Add \(title)", systemImage: "plus.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("contact-add-\(kind.rawValue)-button")
        }
    }

    // MARK: - Field actions

    func addField(kind: FieldKind) {
        do {
            let field = try store.addField(kind, to: contact)
            focusedFieldID = field.persistentModelID
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ offsets: IndexSet, from fields: [ContactField]) {
        do {
            try store.delete(offsets.map { fields[$0] })
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
