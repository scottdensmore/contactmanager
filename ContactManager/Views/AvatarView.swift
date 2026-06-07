//
//  AvatarView.swift
//  ContactManager
//
//  Circular avatar: shows the contact's photo when set, otherwise their
//  initials over a stable per-contact tinted gradient.
//

import AppKit
import SwiftUI

struct AvatarView: View {
    let contact: Contact
    var size: CGFloat = 64

    /// Decoded once per photo change rather than on every body evaluation
    /// (important for list rows that re-render frequently).
    @State private var photo: NSImage?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let photo {
                Image(nsImage: photo)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Circle()
                    .fill(gradient)
                    .overlay {
                        Text(contact.initials)
                            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                    }
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        // The avatar is always shown next to the contact's name (in list
        // rows, the detail header, duplicate rows); treating it as
        // decorative keeps VoiceOver from announcing a redundant "Image".
        .accessibilityHidden(true)
        .task(id: contact.photoData) {
            let decoded = contact.photoData.flatMap { NSImage(data: $0) }
            // Animate the actual swap, which happens when `photo` updates —
            // unless the user has asked to reduce motion.
            withAnimation(reduceMotion ? nil : .smooth) { photo = decoded }
        }
    }

    /// A stable per-contact color so avatars stay visually distinct.
    private var gradient: LinearGradient {
        let palette: [Color] = [.blue, .indigo, .teal, .pink, .orange, .purple, .green, .red]
        let base = palette[contact.avatarPaletteIndex(count: palette.count)]
        return LinearGradient(
            colors: [base, base.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
