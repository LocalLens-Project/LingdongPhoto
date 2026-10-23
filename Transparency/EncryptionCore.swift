// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import CryptoKit
import CommonCrypto
import Security

enum ReferenceError: Error {
    case invalidFormat, randomFailure, derivationFailure
}

extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    init?(base64URL: String) {
        var value = base64URL.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        value += String(repeating: "=", count: (4 - value.count % 4) % 4)
        self.init(base64Encoded: value)
    }
}

struct ReferenceCipher: Codable {
    let iv: String
    let ciphertext: String

    static func seal(_ data: Data, key: Data, aad: String, testNonce: Data? = nil) throws -> Self {
        guard key.count == 32 else { throw ReferenceError.invalidFormat }
        let nonce = try testNonce.map { try AES.GCM.Nonce(data: $0) }
        let box = try AES.GCM.seal(data, using: SymmetricKey(data: key), nonce: nonce,
                                   authenticating: Data(aad.utf8))
        return Self(iv: Data(box.nonce).base64URL, ciphertext: (box.ciphertext + box.tag).base64URL)
    }

    func open(key: Data, aad: String) throws -> Data {
        guard key.count == 32, let nonce = Data(base64URL: iv), nonce.count == 12,
              let combined = Data(base64URL: ciphertext), combined.count >= 16 else {
            throw ReferenceError.invalidFormat
        }
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce),
                                       ciphertext: combined.dropLast(16), tag: combined.suffix(16))
        return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: Data(aad.utf8))
    }
}

enum ReferenceEncryption {
    static let iterations = 600_000

    static func random(_ count: Int = 32) throws -> Data {
        guard count > 0 else { throw ReferenceError.invalidFormat }
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw ReferenceError.randomFailure
        }
        return Data(bytes)
    }

    static func passwordKey(_ password: String, salt: Data) throws -> Data {
        let bytes = Array(password.utf8)
        guard !bytes.isEmpty, salt.count == 16 else { throw ReferenceError.invalidFormat }
        var output = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeBytes { p in salt.withUnsafeBytes { s in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), p.bindMemory(to: Int8.self).baseAddress!,
                                bytes.count, s.bindMemory(to: UInt8.self).baseAddress!, salt.count,
                                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations), &output, 32)
        } }
        guard status == kCCSuccess else { throw ReferenceError.derivationFailure }
        return Data(output)
    }

    static func bodyAAD(id: String, palette: String, style: String) -> String {
        "lingdong-letter-v1:\(id):\(palette):\(style):1"
    }

    static func keyAAD(id: String) -> String { "lingdong-letter-v1:\(id):key" }

    static func shareURL(base: URL, id: String, key: Data?, passwordMode: Bool) -> URL {
        var parts = URLComponents(url: base.appendingPathComponent("letter/" + id), resolvingAgainstBaseURL: false)!
        parts.fragment = passwordMode ? "mode=password" : key.map { "k=" + $0.base64URL }
        return parts.url!
    }
}
