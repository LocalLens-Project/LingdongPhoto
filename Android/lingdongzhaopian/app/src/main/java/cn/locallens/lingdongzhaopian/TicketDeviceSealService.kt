package cn.locallens.lingdongzhaopian

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import java.math.BigInteger
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec

object TicketDeviceSealService : TicketEnvelopeSigner {
    private const val KEYSTORE = "AndroidKeyStore"
    private const val ALIAS = "lingdong-ticket-device-seal-v1"

    @Volatile
    private var cachedKeyPair: KeyPair? = null

    @Volatile
    private var cachedOrigin: TicketSealOrigin? = null

    override fun signature(payloadData: ByteArray): TicketEnvelopeSignature = synchronized(this) {
        val keyPair = cachedKeyPair ?: loadOrCreateKeyPair().also { cachedKeyPair = it }
        val origin = cachedOrigin ?: keyOrigin(keyPair).also { cachedOrigin = it }
        val publicKey = (keyPair.public as ECPublicKey).x963Representation()
        val signature = Signature.getInstance("SHA256withECDSA").run {
            initSign(keyPair.private)
            update(TicketEnvelopeSignature.signingData(payloadData, publicKey, origin))
            sign()
        }
        TicketEnvelopeSignature(
            publicKey = publicKey,
            signature = signature,
            origin = origin,
        )
    }

    fun currentOrigin(): TicketSealOrigin = synchronized(this) {
        cachedOrigin ?: runCatching {
            val pair = cachedKeyPair ?: loadOrCreateKeyPair().also { cachedKeyPair = it }
            keyOrigin(pair).also { cachedOrigin = it }
        }.getOrDefault(TicketSealOrigin.AndroidSoftware)
    }

    private fun loadOrCreateKeyPair(): KeyPair {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        val existing = keyStore.getEntry(ALIAS, null) as? KeyStore.PrivateKeyEntry
        if (existing != null) return KeyPair(existing.certificate.publicKey, existing.privateKey)

        return try {
            generateKeyPair(strongBox = true)
        } catch (_: StrongBoxUnavailableException) {
            generateKeyPair(strongBox = false)
        } catch (_: java.security.InvalidAlgorithmParameterException) {
            generateKeyPair(strongBox = false)
        }
    }

    private fun generateKeyPair(strongBox: Boolean): KeyPair {
        val parameters = KeyGenParameterSpec.Builder(
            ALIAS,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(false)
            .setIsStrongBoxBacked(strongBox)
            .build()
        return KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, KEYSTORE).run {
            initialize(parameters)
            generateKeyPair()
        }
    }

    private fun keyOrigin(keyPair: KeyPair): TicketSealOrigin {
        val info = runCatching {
            KeyFactory.getInstance(keyPair.private.algorithm, KEYSTORE)
                .getKeySpec(keyPair.private, KeyInfo::class.java)
        }.getOrNull() ?: return TicketSealOrigin.AndroidSoftware
        return if (
            info.securityLevel == KeyProperties.SECURITY_LEVEL_STRONGBOX ||
            info.securityLevel == KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT
        ) {
            TicketSealOrigin.AndroidHardware
        } else {
            TicketSealOrigin.AndroidSoftware
        }
    }

    private fun ECPublicKey.x963Representation(): ByteArray =
        byteArrayOf(0x04) + affineX.toFixedUnsigned(32) + affineY.toFixedUnsigned(32)

    private val ECPublicKey.affineX: BigInteger get() = w.affineX
    private val ECPublicKey.affineY: BigInteger get() = w.affineY

    private fun BigInteger.toFixedUnsigned(size: Int): ByteArray {
        val raw = toByteArray()
        val unsigned = if (raw.size > size && raw.first() == 0.toByte()) raw.drop(1).toByteArray() else raw
        require(unsigned.size <= size)
        return ByteArray(size - unsigned.size) + unsigned
    }
}
