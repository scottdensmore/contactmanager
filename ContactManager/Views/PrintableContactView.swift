//
//  PrintableContactView.swift
//  ContactManager
//
//  A fixed-width card layout for a single contact, rendered to PDF (and the
//  print sheet) by `ContactPDF`. Standalone — it reads only the contact, so
//  it renders the same off-screen as it would on-screen.
//

import SwiftUI

struct PrintableContactView: View {
    let contact: Contact

    private let width: CGFloat = 480

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            fields(contact.emails, title: "Email")
            fields(contact.phones, title: "Phone")
            address
            birthday
            notes
        }
        .padding(32)
        .frame(width: width, alignment: .leading)
        .background(.white)
        .foregroundStyle(.black)
    }

    private var header: some View {
        HStack(spacing: 16) {
            AvatarView(contact: contact, size: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .font(.title.weight(.semibold))
                let role = [contact.jobTitle, contact.company]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !role.isEmpty {
                    Text(role).font(.headline).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func fields(_ fields: [ContactField], title: String) -> some View {
        let nonEmpty = fields.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        if !nonEmpty.isEmpty {
            section(title) {
                ForEach(nonEmpty) { field in
                    labeledRow(field.label.title, field.value)
                }
            }
        }
    }

    @ViewBuilder
    private var address: some View {
        let lines = [
            contact.street,
            [contact.city, contact.state, contact.postalCode]
                .filter { !$0.isEmpty }.joined(separator: " "),
            contact.country,
        ].filter { !$0.isEmpty }
        if !lines.isEmpty {
            section("Address") {
                ForEach(lines, id: \.self) { Text($0) }
            }
        }
    }

    @ViewBuilder
    private var birthday: some View {
        if let date = contact.birthday {
            section("Birthday") {
                Text(formattedBirthday(date))
            }
        }
    }

    @ViewBuilder
    private var notes: some View {
        if !contact.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            section("Notes") {
                Text(contact.notes)
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .font(.body)
        }
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
            Text(value)
        }
    }

    private func formattedBirthday(_ date: Date) -> String {
        let fields = Birthday.fields(of: date)
        let months = Calendar(identifier: .gregorian).monthSymbols
        let month = (1 ... 12).contains(fields.month) ? months[fields.month - 1] : ""
        if let year = fields.year {
            return "\(month) \(fields.day), \(year)"
        }
        return "\(month) \(fields.day)"
    }
}
