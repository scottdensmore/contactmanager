//
//  ContactDetailView+Photo.swift
//  ContactManager
//
//  Avatar import/remove handlers for the detail view's photo well. Split
//  out of ContactDetailView so the main file stays focused on layout.
//

import Foundation
import SwiftUI

extension ContactDetailView {
    @MainActor
    func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            Task {
                // Read the file and run the avatar pipeline off the main actor
                // so a multi-megabyte photo can't hitch the UI.
                let avatar: Data? = await Task.detached {
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                    // Decode straight from the file via ImageIO so a huge image
                    // is downsampled to a thumbnail without ever loading its
                    // full raw bytes into memory (dropping a 300 MB file no
                    // longer allocates 300 MB).
                    return ImageProcessing.avatarData(from: url)
                }.value

                guard let avatar else {
                    errorMessage = "That file couldn't be read as an image."
                    return
                }
                do {
                    try store.setPhotoData(avatar, on: contact)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    func removePhoto() {
        do {
            try store.setPhotoData(nil, on: contact)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
