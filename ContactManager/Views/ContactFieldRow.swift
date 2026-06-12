//
//  ContactFieldRow.swift
//  ContactManager
//
//  A single editable email/phone row.
//

import SwiftData
import SwiftUI

struct ContactFieldRow: View {
    @Bindable var field: ContactField
    var focusedFieldID: FocusState<PersistentIdentifier?>.Binding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Picker("", selection: $field.label) {
                ForEach(FieldLabel.allCases) { label in
                    Text(label.title).tag(label)
                }
            }
            .labelsHidden()
            .frame(width: 92, alignment: .leading)
            .accessibilityLabel(field.kind == .email ? "Email label" : "Phone label")
            .accessibilityIdentifier(
                field.kind == .email ? "contact-email-label-picker" : "contact-phone-label-picker"
            )

            TextField(placeholder, text: $field.value)
                .textContentType(field.kind == .email ? .emailAddress : .telephoneNumber)
                .focused(focusedFieldID, equals: field.persistentModelID)
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
