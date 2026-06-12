//
//  ContactDetailView+QuickInfo.swift
//  ContactManager
//
//  Primary email/phone action rows for the contact detail header.
//

import AppKit
import SwiftUI

extension ContactDetailView {
    var identityHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            photoWell
            VStack(alignment: .leading, spacing: 6) {
                Text(contact.fullName)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)
                if let role = contact.roleLine {
                    Text(role)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let primaryLine = contact.primaryReachabilityLine {
                    Label(primaryLine, systemImage: "person.text.rectangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("contact-detail-identity-header")
    }

    var summaryChipRow: some View {
        HStack(spacing: 8) {
            ForEach(summaryChips, id: \.self) { chip in
                Text(chip)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summaryChips.joined(separator: ", "))
        .accessibilityIdentifier("contact-detail-summary-chips")
    }

    var primaryActionRow: some View {
        HStack(spacing: 8) {
            if let email = contact.primaryEmail, let url = ContactLink.mailto(email) {
                Link(destination: url) {
                    Label("Email", systemImage: "envelope")
                }
                .buttonStyle(.borderless)
                .help("Send Email")
            }
            if let phone = contact.primaryPhone, let url = ContactLink.tel(phone) {
                Link(destination: url) {
                    Label("Call", systemImage: "phone")
                }
                .buttonStyle(.borderless)
                .help("Call")
            }
            Button {
                markContacted(contact)
            } label: {
                Label("Mark Contacted", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Mark Contacted Today")
        }
        .labelStyle(.titleAndIcon)
        .controlSize(.small)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("contact-detail-primary-actions")
    }

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

    var summaryChips: [String] {
        var chips: [String] = []
        let contact = contact
        if !contact.emails.isEmpty {
            chips.append("\(contact.emails.count) email\(contact.emails.count == 1 ? "" : "s")")
        }
        if !contact.phones.isEmpty {
            chips.append("\(contact.phones.count) phone\(contact.phones.count == 1 ? "" : "s")")
        }
        if !contact.groups.isEmpty {
            chips.append("\(contact.groups.count) group\(contact.groups.count == 1 ? "" : "s")")
        }
        if !contact.tags.isEmpty {
            chips.append("\(contact.tags.count) tag\(contact.tags.count == 1 ? "" : "s")")
        }
        if contact.lastContactedAt == nil { chips.append("Needs follow-up") }
        if contact.birthday != nil { chips.append("Birthday saved") }
        return chips
    }
}

extension Contact {
    var primaryReachabilityLine: String? {
        switch (primaryEmail, primaryPhone) {
        case (.some(let email), .some(let phone)): "\(email) · \(phone)"
        case (.some(let email), .none): email
        case (.none, .some(let phone)): phone
        case (.none, .none): nil
        }
    }
}
