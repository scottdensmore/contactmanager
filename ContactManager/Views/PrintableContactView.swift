//
//  PrintableContactView.swift
//  ContactManager
//
//  A fixed-width card layout for a single contact, rendered to PDF (and the
//  print sheet) by `ContactPDF`. Standalone — it reads only the contact, so
//  it renders the same off-screen as it would on-screen.
//

import AppKit
import SwiftUI

struct PrintableContactView: View {
    let contact: Contact

    private let width: CGFloat = 480
    private let avatarSize: CGFloat = 64

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
            printableAvatar
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .font(.title.weight(.semibold))
                if let role = contact.roleLine {
                    Text(role).font(.headline).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// A synchronous avatar: `ImageRenderer` renders off-screen and never runs
    /// `AvatarView`'s async `.task`, so the photo is decoded inline here (with
    /// the same initials-over-gradient fallback) to ensure it's in the PDF.
    private var printableAvatar: some View {
        Group {
            if let data = contact.photoData, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Circle()
                    .fill(avatarGradient)
                    .overlay {
                        Text(contact.initials)
                            .font(.system(size: avatarSize * 0.4, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                    }
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
    }

    /// Mirrors `AvatarView`'s stable per-contact gradient (kept in sync
    /// deliberately; the print layout needs a synchronous variant).
    private var avatarGradient: LinearGradient {
        let palette: [Color] = [.blue, .indigo, .teal, .pink, .orange, .purple, .green, .red]
        let index = ((contact.colorSeed % palette.count) + palette.count) % palette.count
        let base = palette[index]
        return LinearGradient(
            colors: [base, base.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
        let lines = contact.addressLines
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
                Text(Birthday.formatted(date))
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
}
