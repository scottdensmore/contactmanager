//
//  ImageProcessingTests.swift
//  ContactManagerTests
//
//  Verifies avatar generation downscales and re-encodes images.
//

@testable import ContactManager
import CoreGraphics
import ImageIO
import Testing
import UniformTypeIdentifiers

struct ImageProcessingTests {
    /// Encodes a solid-color image of the given size as PNG data.
    private func makePNG(width: Int, height: Int) throws -> Data {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())

        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func pixelSize(of data: Data) throws -> (width: Int, height: Int) {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return (image.width, image.height)
    }

    @Test func downscalesImagesLargerThanTheMaxEdge() throws {
        let input = try makePNG(width: 1024, height: 768)
        let avatar = try #require(ImageProcessing.avatarData(from: input))

        let size = try pixelSize(of: avatar)
        #expect(max(size.width, size.height) <= Int(ImageProcessing.maxPixelSize))
        // Aspect ratio is preserved: 1024x768 → 512x384.
        #expect(size.width == 512)
        #expect(size.height == 384)
    }

    @Test func returnsNilForNonImageData() {
        let garbage = Data("not an image".utf8)
        #expect(ImageProcessing.avatarData(from: garbage) == nil)
    }
}
