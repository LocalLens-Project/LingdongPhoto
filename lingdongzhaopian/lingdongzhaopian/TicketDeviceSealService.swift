// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import CryptoKit
import Foundation
import Security

enum TicketDeviceSealCapability: Equatable {
    case secureEnclave
    case simulatorTest
    case unavailable

    var shortDescription: String {
        switch self {
        case .secureEnclave:
            "由这台 iPhone 的安全隔区保管密钥"
        case .simulatorTest:
            "模拟器没有安全隔区，当前只测试跨端验真流程"
        case .unavailable:
            "这台设备暂时无法使用安全隔区"
        }
    }
}

enum TicketDeviceSealError: LocalizedError {
    case secureEnclaveUnavailable
    case keychain(OSStatus)
    case accessControl

    var errorDescription: String? {
        switch self {
        case .secureEnclaveUnavailable:
            "无法使用这台 iPhone 的安全隔区，请关闭“设备封印”后再生成二维码。".appLocalized
        case .keychain:
            "无法读取这台设备保存的票根密钥，请稍后重试。".appLocalized
        case .accessControl:
            "无法建立安全隔区保护，请稍后重试。".appLocalized
        }
    }
}

/// Signs the exact public JSON bytes carried by the QR envelope. On a physical
/// iPhone this type has no software-key fallback: an enabled seal either uses
/// `SecureEnclave.P256.Signing.PrivateKey` or reports that it is unavailable.
/// Simulators use an explicitly labelled test key because they have no Secure
/// Enclave; the test origin is visible to every verifier and cannot be confused
/// with a hardware-backed seal.
nonisolated final class TicketDeviceSealService: TicketEnvelopeSigning, @unchecked Sendable {
    static let shared = TicketDeviceSealService()

    private let lock = NSLock()
    private var cachedSignatures: [Data: TicketEnvelopeSignature] = [:]

#if targetEnvironment(simulator)
    private var cachedPrivateKey: P256.Signing.PrivateKey?
#else
    private var cachedPrivateKey: SecureEnclave.P256.Signing.PrivateKey?
#endif

    private let keychainService = "cn.locallens.lingdongphoto.ticket-device-seal.v1"
    private let keychainAccount = "p256-signing-key"

    private init() {}

    var capability: TicketDeviceSealCapability {
#if targetEnvironment(simulator)
        .simulatorTest
#else
        SecureEnclave.isAvailable ? .secureEnclave : .unavailable
#endif
    }

    func signature(for payloadData: Data) throws -> TicketEnvelopeSignature {
        let digest = Data(SHA256.hash(data: payloadData))
        lock.lock()
        if let cached = cachedSignatures[digest] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let result = try makeSignature(for: payloadData)

        lock.lock()
        if cachedSignatures.count >= 16 {
            cachedSignatures.removeAll(keepingCapacity: true)
        }
        cachedSignatures[digest] = result
        lock.unlock()
        return result
    }

    private func makeSignature(for payloadData: Data) throws -> TicketEnvelopeSignature {
#if targetEnvironment(simulator)
        return try simulatorSignature(for: payloadData)
#else
        guard SecureEnclave.isAvailable else {
            throw TicketDeviceSealError.secureEnclaveUnavailable
        }
        do {
            return try secureEnclaveSignature(for: payloadData)
        } catch {
            lock.lock()
            let hasCachedKey = cachedPrivateKey != nil
            lock.unlock()
            guard hasCachedKey else { throw error }
            cachedPrivateKey = nil
            deleteKeychainData()
            return try secureEnclaveSignature(for: payloadData)
        }
#endif
    }

#if targetEnvironment(simulator)
    private func simulatorSignature(for payloadData: Data) throws -> TicketEnvelopeSignature {
        let key = try simulatorPrivateKey()
        let publicKey = key.publicKey.x963Representation
        let signingData = TicketEnvelopeSignature.signingData(
            payloadData: payloadData,
            publicKey: publicKey,
            origin: .simulatorTest
        )
        let signature = try key.signature(for: signingData)
        return TicketEnvelopeSignature(
            publicKey: publicKey,
            signature: signature.derRepresentation,
            origin: .simulatorTest
        )
    }
#endif

#if !targetEnvironment(simulator)
    private func secureEnclaveSignature(for payloadData: Data) throws -> TicketEnvelopeSignature {
        let key = try secureEnclavePrivateKey()
        let publicKey = key.publicKey.x963Representation
        let signingData = TicketEnvelopeSignature.signingData(
            payloadData: payloadData,
            publicKey: publicKey,
            origin: .appleSecureEnclave
        )
        let signature = try key.signature(for: signingData)
        return TicketEnvelopeSignature(
            publicKey: publicKey,
            signature: signature.derRepresentation,
            origin: .appleSecureEnclave
        )
    }
#endif

#if targetEnvironment(simulator)
    private func simulatorPrivateKey() throws -> P256.Signing.PrivateKey {
        if let cachedPrivateKey { return cachedPrivateKey }
        let key: P256.Signing.PrivateKey
        if let stored = try? keychainData() {
            key = try P256.Signing.PrivateKey(rawRepresentation: stored)
        } else {
            key = P256.Signing.PrivateKey()
            // Unsigned simulator builds can lack the application identifier
            // entitlement required by Keychain. Persistence is useful for UI
            // testing but is not part of the simulator's security guarantee.
            try? storeKeychainData(key.rawRepresentation)
        }
        cachedPrivateKey = key
        return key
    }
#else
    private func secureEnclavePrivateKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        lock.lock()
        if let cached = cachedPrivateKey {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let key: SecureEnclave.P256.Signing.PrivateKey
        if let stored = try keychainData(),
           let restored = try? SecureEnclave.P256.Signing.PrivateKey(
               dataRepresentation: stored
           ) {
            key = restored
        } else {
            deleteKeychainData()
            var accessError: Unmanaged<CFError>?
            guard let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .privateKeyUsage,
                &accessError
            ) else {
                throw TicketDeviceSealError.accessControl
            }
            key = try SecureEnclave.P256.Signing.PrivateKey(
                compactRepresentable: false,
                accessControl: accessControl
            )
            try storeKeychainData(key.dataRepresentation)
        }
        lock.lock()
        cachedPrivateKey = key
        lock.unlock()
        return key
    }
#endif

    private func keychainData() throws -> Data? {
        var query = keychainIdentity
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw TicketDeviceSealError.keychain(status)
        }
        return result as? Data
    }

    private func storeKeychainData(_ data: Data) throws {
        var query = keychainIdentity
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw TicketDeviceSealError.keychain(updateStatus)
        }
        query[kSecValueData as String] = data
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw TicketDeviceSealError.keychain(addStatus)
        }
    }

    private func deleteKeychainData() {
        SecItemDelete(keychainIdentity as CFDictionary)
    }

    private var keychainIdentity: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
    }
}
