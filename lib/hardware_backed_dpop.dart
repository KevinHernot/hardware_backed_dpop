import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'hardware_backed_dpop_platform_interface.dart';
import 'src/dpop_binding_material.dart';

export 'src/dpop_binding_material.dart';

final Random _secureRandom = Random.secure();

/// Public Dart API for the hardware-backed DPoP plugin.
class HardwareBackedDpop {
  const HardwareBackedDpop();

  /// Rotates the current binding by deleting any existing key and minting a new one.
  Future<DpopBindingMaterial> rotateBinding() {
    return HardwareBackedDpopPlatform.instance.rotateBinding();
  }

  /// Returns the current binding or creates one if needed.
  Future<DpopBindingMaterial> getOrCreateBinding() {
    return HardwareBackedDpopPlatform.instance.getOrCreateBinding();
  }

  /// Returns the current binding if one already exists on the device.
  Future<DpopBindingMaterial?> getExistingBinding() {
    return HardwareBackedDpopPlatform.instance.getExistingBinding();
  }

  /// Signs a precomputed JWS signing input using the native private key.
  Future<String> signJwsSigningInput(String signingInput) {
    return HardwareBackedDpopPlatform.instance.signJwsSigningInput(signingInput);
  }

  /// Deletes the current platform binding.
  Future<void> deleteBinding() {
    return HardwareBackedDpopPlatform.instance.deleteBinding();
  }

  /// Builds and signs a DPoP proof JWT.
  ///
  /// The [htu] value is typically the protected request URL, but it can also be
  /// any stricter server-defined request target so long as the backend verifies
  /// the same contract.
  Future<String> buildProof({
    required String htu,
    String htm = 'POST',
    String? accessToken,
    String? nonce,
    String? jti,
    DateTime? issuedAt,
    DpopBindingMaterial? binding,
    Map<String, Object?> additionalPayloadClaims = const {},
  }) async {
    final normalizedHtu = htu.trim();
    if (normalizedHtu.isEmpty) {
      throw ArgumentError.value(htu, 'htu', 'must not be empty');
    }

    final normalizedHtm = htm.trim().toUpperCase();
    if (normalizedHtm.isEmpty) {
      throw ArgumentError.value(htm, 'htm', 'must not be empty');
    }

    final resolvedBinding = binding ?? await getOrCreateBinding();
    final resolvedJti = jti?.trim();
    final issuedAtSeconds =
        (issuedAt ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;

    final header = <String, Object?>{
      'typ': 'dpop+jwt',
      'alg': 'ES256',
      'jwk': resolvedBinding.jwk,
    };

    final payload = <String, Object?>{
      'iat': issuedAtSeconds,
      'jti': resolvedJti != null && resolvedJti.isNotEmpty
          ? resolvedJti
          : generateProofJti(),
      'htm': normalizedHtm,
      'htu': normalizedHtu,
    };

    if (accessToken != null && accessToken.isNotEmpty) {
      payload['ath'] = _base64UrlNoPadding(
        sha256.convert(utf8.encode(accessToken)).bytes,
      );
    }

    if (nonce != null && nonce.isNotEmpty) {
      payload['nonce'] = nonce;
    }

    for (final entry in additionalPayloadClaims.entries) {
      if (payload.containsKey(entry.key)) {
        throw ArgumentError.value(
          entry.key,
          'additionalPayloadClaims',
          'must not override a reserved DPoP claim',
        );
      }
      payload[entry.key] = entry.value;
    }

    final signingInput =
        '${_jsonSegment(header)}.${_jsonSegment(payload)}';
    final encodedSignature = await signJwsSigningInput(signingInput);
    return '$signingInput.$encodedSignature';
  }

  /// Generates a random proof ID suitable for the DPoP `jti` claim.
  String generateProofJti() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

String _jsonSegment(Map<String, Object?> value) {
  return _base64UrlNoPadding(utf8.encode(jsonEncode(value)));
}

String _base64UrlNoPadding(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}
