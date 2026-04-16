import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Public binding material derived from the native ES256 key pair.
class DpopBindingMaterial {
  DpopBindingMaterial({
    required this.rawPublicKey,
    required this.jkt,
    required Map<String, String> jwk,
  }) : jwk = Map.unmodifiable(jwk);

  factory DpopBindingMaterial.fromMap(Map<Object?, Object?> map) {
    final rawPublicKey = map['rawPublicKey'] as String?;
    final jkt = map['jkt'] as String?;
    final jwkDynamic = map['jwk'];

    Map<String, String> jwk;
    if (jwkDynamic is Map) {
      jwk = jwkDynamic.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } else if (jwkDynamic is String && jwkDynamic.isNotEmpty) {
      final decoded = jsonDecode(jwkDynamic);
      if (decoded is! Map) {
        throw const FormatException('Invalid DPoP JWK payload');
      }
      jwk = decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } else {
      throw const FormatException('Missing DPoP JWK payload');
    }

    if (rawPublicKey == null || rawPublicKey.isEmpty) {
      throw const FormatException('Missing DPoP raw public key');
    }
    if (jkt == null || jkt.isEmpty) {
      throw const FormatException('Missing DPoP thumbprint');
    }

    return DpopBindingMaterial(
      rawPublicKey: rawPublicKey,
      jkt: jkt,
      jwk: jwk,
    );
  }

  final String rawPublicKey;
  final String jkt;
  final Map<String, String> jwk;

  Map<String, Object?> toJson() {
    return {
      'rawPublicKey': rawPublicKey,
      'jkt': jkt,
      'jwk': jwk,
    };
  }

  @override
  String toString() {
    return 'DpopBindingMaterial(rawPublicKey: $rawPublicKey, jkt: $jkt, jwk: $jwk)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DpopBindingMaterial &&
        other.rawPublicKey == rawPublicKey &&
        other.jkt == jkt &&
        mapEquals(other.jwk, jwk);
  }

  @override
  int get hashCode {
    return Object.hash(
      rawPublicKey,
      jkt,
      Object.hashAll(jwk.entries.map((entry) => Object.hash(entry.key, entry.value))),
    );
  }
}