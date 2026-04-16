package com.example.hardware_backed_dpop

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.math.BigInteger
import java.nio.charset.StandardCharsets
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec

class HardwareBackedDpopPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    private val dpopKeyAlias = "com.example.hardware_backed_dpop.es256"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "hardware_backed_dpop")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getOrCreateBinding" -> {
                try {
                    result.success(getOrCreateBinding())
                } catch (e: Exception) {
                    result.error("DPOP_BINDING_ERROR", e.message, null)
                }
            }
            "getExistingBinding" -> {
                try {
                    result.success(getExistingBinding())
                } catch (e: Exception) {
                    result.error("DPOP_BINDING_ERROR", e.message, null)
                }
            }
            "signJwsSigningInput" -> {
                val signingInput = call.argument<String>("signingInput")
                if (signingInput.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENTS", "signingInput is required", null)
                } else {
                    try {
                        result.success(signJwsSigningInput(signingInput))
                    } catch (e: Exception) {
                        result.error("DPOP_SIGN_ERROR", e.message, null)
                    }
                }
            }
            "deleteBinding" -> {
                try {
                    deleteBinding()
                    result.success(true)
                } catch (e: Exception) {
                    result.error("DPOP_DELETE_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun getOrCreateBinding(): Map<String, Any> {
        val entry = getDpopKeyEntry() ?: createDpopKeyEntry()
        return buildDpopBinding(entry)
    }

    private fun getExistingBinding(): Map<String, Any>? {
        val entry = getDpopKeyEntry() ?: return null
        return buildDpopBinding(entry)
    }

    private fun signJwsSigningInput(signingInput: String): String {
        val entry = getDpopKeyEntry() ?: createDpopKeyEntry()
        val signature = Signature.getInstance("SHA256withECDSA")
        signature.initSign(entry.privateKey)
        signature.update(signingInput.toByteArray(StandardCharsets.UTF_8))
        val derSignature = signature.sign()
        return base64UrlEncode(derEcdsaSignatureToJose(derSignature, 64))
    }

    private fun deleteBinding() {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (keyStore.containsAlias(dpopKeyAlias)) {
            keyStore.deleteEntry(dpopKeyAlias)
        }
    }

    private fun buildDpopBinding(entry: KeyStore.PrivateKeyEntry): Map<String, Any> {
        val publicKey = entry.certificate.publicKey as? ECPublicKey
            ?: throw IllegalStateException("DPoP key is not an EC public key")
        val x = toUnsignedFixedLength(publicKey.w.affineX, 32)
        val y = toUnsignedFixedLength(publicKey.w.affineY, 32)
        val rawPublicKey = byteArrayOf(0x04) + x + y
        val jwk = mapOf(
            "kty" to "EC",
            "crv" to "P-256",
            "x" to base64UrlEncode(x),
            "y" to base64UrlEncode(y),
        )
        return mapOf(
            "rawPublicKey" to base64UrlEncode(rawPublicKey),
            "jkt" to computeJwkThumbprint(jwk),
            "jwk" to jwk,
        )
    }

    private fun getDpopKeyEntry(): KeyStore.PrivateKeyEntry? {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val entry = keyStore.getEntry(dpopKeyAlias, null)
        return entry as? KeyStore.PrivateKeyEntry
    }

    private fun createDpopKeyEntry(): KeyStore.PrivateKeyEntry {
        val generator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            "AndroidKeyStore"
        )

        val baseSpec = KeyGenParameterSpec.Builder(
            dpopKeyAlias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(false)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                baseSpec.setIsStrongBoxBacked(true)
            }
            generator.initialize(baseSpec.build())
        } catch (_: StrongBoxUnavailableException) {
            generator.initialize(buildFallbackSpec())
        } catch (_: Exception) {
            generator.initialize(buildFallbackSpec())
        }

        generator.generateKeyPair()
        return getDpopKeyEntry()
            ?: throw IllegalStateException("Failed to create Android Keystore DPoP key")
    }

    private fun buildFallbackSpec(): KeyGenParameterSpec {
        return KeyGenParameterSpec.Builder(
            dpopKeyAlias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(false)
            .build()
    }

    private fun computeJwkThumbprint(jwk: Map<String, String>): String {
        val canonical =
            "{\"crv\":\"${jwk["crv"]}\",\"kty\":\"${jwk["kty"]}\",\"x\":\"${jwk["x"]}\",\"y\":\"${jwk["y"]}\"}"
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(canonical.toByteArray(StandardCharsets.UTF_8))
        return base64UrlEncode(digest)
    }

    private fun base64UrlEncode(bytes: ByteArray): String = android.util.Base64.encodeToString(
        bytes,
        android.util.Base64.NO_WRAP or
            android.util.Base64.NO_PADDING or
            android.util.Base64.URL_SAFE,
    )

    private fun toUnsignedFixedLength(value: BigInteger, size: Int): ByteArray {
        val bytes = value.toByteArray()
        return when {
            bytes.size == size -> bytes
            bytes.size == size + 1 && bytes[0] == 0.toByte() -> bytes.copyOfRange(1, bytes.size)
            bytes.size < size -> ByteArray(size - bytes.size) + bytes
            else -> throw IllegalArgumentException("Integer does not fit expected length")
        }
    }

    private fun derEcdsaSignatureToJose(derSignature: ByteArray, outputLength: Int): ByteArray {
        if (derSignature.isEmpty() || derSignature[0].toInt() != 0x30) {
            throw IllegalArgumentException("Invalid DER ECDSA signature")
        }

        val sequenceLengthInfo = readAsn1Length(derSignature, 1)
        var offset = sequenceLengthInfo.second

        if (offset >= derSignature.size || derSignature[offset].toInt() != 0x02) {
            throw IllegalArgumentException("Invalid DER ECDSA signature (missing r)")
        }
        val rLengthInfo = readAsn1Length(derSignature, offset + 1)
        val rStart = rLengthInfo.second
        val rEnd = rStart + rLengthInfo.first
        val r = derSignature.copyOfRange(rStart, rEnd)
        offset = rEnd

        if (offset >= derSignature.size || derSignature[offset].toInt() != 0x02) {
            throw IllegalArgumentException("Invalid DER ECDSA signature (missing s)")
        }
        val sLengthInfo = readAsn1Length(derSignature, offset + 1)
        val sStart = sLengthInfo.second
        val sEnd = sStart + sLengthInfo.first
        val s = derSignature.copyOfRange(sStart, sEnd)

        val componentLength = outputLength / 2
        return toUnsignedFixedLength(BigInteger(1, r), componentLength) +
            toUnsignedFixedLength(BigInteger(1, s), componentLength)
    }

    private fun readAsn1Length(bytes: ByteArray, offset: Int): Pair<Int, Int> {
        val first = bytes[offset].toInt() and 0xFF
        return if ((first and 0x80) == 0) {
            first to (offset + 1)
        } else {
            val count = first and 0x7F
            var length = 0
            for (index in 0 until count) {
                length = (length shl 8) or (bytes[offset + 1 + index].toInt() and 0xFF)
            }
            length to (offset + 1 + count)
        }
    }
}