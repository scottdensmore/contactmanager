//
//  ContactFieldRow.swift
//  ContactManager
//
//  A single editable email/phone row.
//

import SwiftUI

struct ContactFieldRow: View {
    @Bindable var field: ContactField

    var body: some View {
        HStack {
            Picker("", selection: $field.label) {
                ForEach(FieldLabel.allCases) { label in
                    Text(label.title).tag(label)
                }
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel(field.kind == .email ? "Email label" : "Phone label")
            .accessibilityIdentifier(
                field.kind == .email ? "contact-email-label-picker" : "contact-phone-label-picker"
            )

            TextField(placeholder, text: $field.value)
                .textContentType(field.kind == .email ? .emailAddress : .telephoneNumber)
                .accessibilityLabel(field.kind == .email ? "Email address" : "Phone number")
                .accessibilityIdentifier(
                    field.kind == .email ? "contact-email-value-field" : "contact-phone-value-field"
                )
        }
    }

    private var placeholder: String {
        field.kind == .email ? "name@example.com" : "Phone"
    }
}
