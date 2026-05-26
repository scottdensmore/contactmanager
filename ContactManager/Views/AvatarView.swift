//
//  AvatarView.swift
//  ContactManager
//
//  Circular avatar: shows the contact's photo when set, otherwise their
//  initials over a stable per-contact tinted gradient.
//

import SwiftUI
import AppKit

struct AvatarView: View {
    let contact: Contact
    var size: CGFloat = 64

    // Decoded once per photo change rather than on every body evaluation
    // (important for list rows that re-render frequently).
    @State private var photo: NSImage?

    var body: some View {
        Group {
            if let photo {
                Image(nsImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(gradient)
                    .overlay {
                        Text(contact.initials)
                            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .animation(.smooth, value: contact.photoData)
        .task(id: contact.photoData) {
            photo = contact.photoData.flatMap { NSImage(data: $0) }
        }
    }

    /// A stable per-contact color so avatars stay visually distinct.
    private var gradient: LinearGradient {
        let palette: [Color] = [.blue, .indigo, .teal, .pink, .orange, .purple, .green, .red]
        // Wrap into range without `abs`, which can trap on Int.min.
        let index = ((contact.colorSeed % palette.count) + palette.count) % palette.count
        let base = palette[index]
        return LinearGradient(
            colors: [base, base.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
