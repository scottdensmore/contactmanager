//
//  ImageProcessing.swift
//  ContactManager
//
//  Downscales and re-encodes picked images into compact avatar JPEGs so the
//  store stays lean. Uses ImageIO thumbnails for efficient decoding.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageProcessing {
    /// Longest edge (in pixels) of a generated avatar.
    static let maxPixelSize: CGFloat = 512

    /// JPEG compression quality for generated avatars.
    static let compressionQuality: Double = 0.8

    /// Reads an image file and returns a downscaled avatar JPEG, or `nil` if
    /// the file isn't a decodable image.
    static func avatarData(from url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return avatarData(from: source)
    }

    /// Returns a downscaled avatar JPEG for the given image data, or `nil` if
    /// the data isn't a decodable image.
    static func avatarData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return avatarData(from: source)
    }

    private static func avatarData(from source: CGImageSource) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }

        CGImageDestinationAddImage(
            destination, thumbnail,
            [kCGImageDestinationLossyCompressionQuality: compressionQuality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
