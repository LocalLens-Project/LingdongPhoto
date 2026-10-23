// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

@main
struct Checks {
    struct Fixture: Codable {
        let id: String
        let aad: String
        let keyAAD: String
        let plaintext: String
        let key: String
        let password: String
        let salt: String
        let iterations: Int
        let body: ReferenceCipher
        let wrappedKey: ReferenceCipher
        let url: String
        let passwordURL: String
    }

    struct Incoming: Codable {
        let plaintext: String
        let key: String
        let aad: String
        let body: ReferenceCipher
    }

    static func rejects(_ label: String, _ action: () throws -> Void) throws {
        var failed = false
        do { try action() } catch { failed = true }
        guard failed else { throw NSError(domain: label, code: 1) }
    }

    static func main() throws {
        if CommandLine.arguments.dropFirst().first == "verify" {
            let fixture = try JSONDecoder().decode(Incoming.self, from: FileHandle.standardInput.readDataToEndOfFile())
            guard let key = Data(base64URL: fixture.key),
                  try fixture.body.open(key: key, aad: fixture.aad) == Data(fixture.plaintext.utf8) else {
                throw ReferenceError.invalidFormat
            }
            print("PASS: Web Crypto ciphertext opened by Swift CryptoKit")
            return
        }
        let id = "00000000-0000-4000-8000-000000000001"
        let key = Data(0..<32), salt = Data(32..<48), nonce = Data(48..<60)
        let plaintext = "Synthetic only · 虚构测试 🌿\nNo personal content."
        let password = "synthetic-password-4.0.0"
        let aad = ReferenceEncryption.bodyAAD(id: id, palette: "cream", style: "classic")
        let keyAAD = ReferenceEncryption.keyAAD(id: id)
        let wrapping = try ReferenceEncryption.passwordKey(password, salt: salt)
        let body = try ReferenceCipher.seal(Data(plaintext.utf8), key: key, aad: aad, testNonce: nonce)
        let wrapped = try ReferenceCipher.seal(key, key: wrapping, aad: keyAAD, testNonce: Data(60..<72))
        let reopened = try body.open(key: key, aad: aad)
        let reopenedKey = try wrapped.open(key: wrapping, aad: keyAAD)
        precondition(reopened == Data(plaintext.utf8))
        precondition(reopenedKey == key)
        var wrongKey = key; wrongKey[0] ^= 1
        try rejects("wrong key") { _ = try body.open(key: wrongKey, aad: aad) }
        try rejects("wrong AAD") { _ = try body.open(key: key, aad: aad + "tampered") }
        var altered = Data(base64URL: body.ciphertext)!; altered[altered.count - 1] ^= 1
        let tampered = ReferenceCipher(iv: body.iv, ciphertext: altered.base64URL)
        try rejects("tampered tag") { _ = try tampered.open(key: key, aad: aad) }
        let randomBody = try ReferenceCipher.seal(Data(plaintext.utf8), key: ReferenceEncryption.random(), aad: aad)
        precondition(Data(base64URL: randomBody.iv)!.count == 12)
        let base = URL(string: "https://example.invalid")!
        let url = ReferenceEncryption.shareURL(base: base, id: id, key: key, passwordMode: false)
        let passwordURL = ReferenceEncryption.shareURL(base: base, id: id, key: nil, passwordMode: true)
        precondition(url.query == nil && passwordURL.fragment == "mode=password")
        precondition(!url.path.contains(key.base64URL))
        let fixture = Fixture(id: id, aad: aad, keyAAD: keyAAD, plaintext: plaintext,
                              key: key.base64URL, password: password, salt: salt.base64URL,
                              iterations: ReferenceEncryption.iterations, body: body, wrappedKey: wrapped,
                              url: url.absoluteString, passwordURL: passwordURL.absoluteString)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(fixture))
    }
}
