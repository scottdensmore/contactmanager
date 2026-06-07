//
//  ContactDetailView+QuickInfo.swift
//  ContactManager
//
//  Primary email/phone action rows for the contact detail header.
//

import AppKit
import SwiftUI

extension ContactDetailView {
    func quickRow(kind: FieldKind, value: String) -> some View {
        let label = kind == .email ? "Email" : "Phone"
        return HStack {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .accessibilityElement(children: .combine)

            if let url = actionURL(for: kind, value: value) {
                Link(destination: url) {
                    Image(systemName: kind == .email ? "envelope" : "phone")
                }
                .buttonStyle(.borderless)
                .help(kind == .email ? "Send Email" : "Call")
                .accessibilityLabel(kind == .email ? "Send Email" : "Call")
            }

            Button {
                copyToPasteboard(value)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy \(label)")
            .accessibilityLabel("Copy \(label)")
        }
    }

    private func actionURL(for kind: FieldKind, value: String) -> URL? {
        switch kind {
        case .email: ContactLink.mailto(value)
        case .phone: ContactLink.tel(value)
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
