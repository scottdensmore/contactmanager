//
//  AvatarView.swift
//  ContactManager
//
//  Circular avatar showing the contact's initials over a tinted gradient.
//  Photo support arrives in a later milestone; this is the fallback.
//

import SwiftUI

struct AvatarView: View {
    let contact: Contact
    var size: CGFloat = 64

    var body: some View {
        Circle()
            .fill(gradient)
            .overlay {
                Text(contact.initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: size, height: size)
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
