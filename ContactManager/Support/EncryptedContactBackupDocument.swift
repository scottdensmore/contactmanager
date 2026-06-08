//
//  EncryptedContactBackupDocument.swift
//  ContactManager
//
//  Password-protected backup document using a versioned JSON envelope.
//

import CommonCrypto
import CryptoKit
import Foundation
import Security
import SwiftUI
import UniformTypeIdentifiers

enum ContactBackupEncryptionError: Error, Equatable, LocalizedError {
    case emptyPassword
    case invalidFormat
    case invalidPassword
    case keyDerivationFailed
    case randomFailure
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .emptyPassword:
            "Enter a password for the encrypted backup."
        case .invalidFormat:
            "That file is not a supported encrypted backup."
        case .invalidPassword:
            "The backup password is incorrect."
        case .keyDerivationFailed:
            "Couldn't derive an encryption key for the backup."
        case .randomFailure:
            "Couldn't create secure random bytes for the backup."
        case .encryptionFailed:
            "Couldn't encrypt the backup."
        }
    }
}

struct EncryptedContactBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    static func encode(_ backup: ContactBackup, password: String) throws -> Data {
        guard !password.isEmpty else { throw ContactBackupEncryptionError.emptyPassword }
        let plaintext = try ContactBackupDocument.encode(backup)
        let salt = try randomBytes(count: 16)
        let key = try key(for: password, salt: salt)
        let box = try AES.GCM.seal(plaintext, using: key)
        guard let combined = box.combined else {
            throw ContactBackupEncryptionError.encryptionFailed
        }

        let envelope = Envelope(salt: salt, sealedData: combined)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    static func decode(_ data: Data, password: String) throws -> ContactBackup {
        guard !password.isEmpty else { throw ContactBackupEncryptionError.emptyPassword }
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw ContactBackupEncryptionError.invalidFormat
        }
        guard envelope.magic == Envelope.magic,
              envelope.version == 1,
              envelope.algorithm == "AES.GCM",
              envelope.kdf == "PBKDF2-HMAC-SHA256"
        else {
            throw ContactBackupEncryptionError.invalidFormat
        }

        let key = try key(for: password, salt: envelope.salt, iterations: envelope.iterations)
        let box: AES.GCM.SealedBox
        do {
            box = try AES.GCM.SealedBox(combined: envelope.sealedData)
        } catch {
            throw ContactBackupEncryptionError.invalidFormat
        }

        do {
            let plaintext = try AES.GCM.open(box, using: key)
            return try ContactBackupDocument.decode(plaintext)
        } catch is DecodingError {
            throw ContactBackupEncryptionError.invalidFormat
        } catch {
            throw ContactBackupEncryptionError.invalidPassword
        }
    }

    static func isEncrypted(_ data: Data) -> Bool {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            return false
        }
        return envelope.magic == Envelope.magic
    }

    private static func key(for password: String, salt: Data, iterations: Int = Envelope.iterations) throws
        -> SymmetricKey {
        let passwordData = Data(password.utf8)
        var keyData = Data(count: 32)
        let keyLength = keyData.count
        let status = keyData.withUnsafeMutableBytes { keyBuffer in
            salt.withUnsafeBytes { saltBuffer in
                passwordData.withUnsafeBytes { passwordBuffer in
                    guard let keyAddress = keyBuffer.baseAddress,
                          let saltAddress = saltBuffer.bindMemory(to: UInt8.self).baseAddress,
                          let passwordAddress = passwordBuffer.bindMemory(to: Int8.self).baseAddress
                    else {
                        return Int32(kCCMemoryFailure)
                    }
                    return CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordAddress,
                        passwordData.count,
                        saltAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        keyAddress,
                        keyLength
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw ContactBackupEncryptionError.keyDerivationFailed
        }
        return SymmetricKey(data: keyData)
    }

    private static func randomBytes(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return errSecAllocate
            }
            return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }
        guard status == errSecSuccess else {
            throw ContactBackupEncryptionError.randomFailure
        }
        return data
    }

    private struct Envelope: Codable {
        static let magic = "ContactManagerEncryptedBackup"
        static let iterations = 210_000

        var magic = Self.magic
        var version = 1
        var algorithm = "AES.GCM"
        var kdf = "PBKDF2-HMAC-SHA256"
        var iterations = Self.iterations
        var salt: Data
        var sealedData: Data
    }
}
