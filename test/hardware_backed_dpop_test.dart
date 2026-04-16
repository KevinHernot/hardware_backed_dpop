import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_backed_dpop/hardware_backed_dpop.dart';
import 'package:hardware_backed_dpop/hardware_backed_dpop_platform_interface.dart';
import 'package:hardware_backed_dpop/hardware_backed_dpop_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHardwareBackedDpopPlatform
    with MockPlatformInterfaceMixin
    implements HardwareBackedDpopPlatform {
  @override
  Future<void> deleteBinding() async {}

  @override
  Future<DpopBindingMaterial?> getExistingBinding() async => null;

  @override
  Future<DpopBindingMaterial> getOrCreateBinding() async {
    return DpopBindingMaterial.fromMap(const {
      'rawPublicKey': 'test-dpop-public-key',
      'jkt': 'test-dpop-jkt',
      'jwk': {
        'kty': 'EC',
        'crv': 'P-256',
        'x': 'test-x',
        'y': 'test-y',
      },
    });
  }

  @override
  Future<DpopBindingMaterial> rotateBinding() => getOrCreateBinding();

  @override
  Future<String> signJwsSigningInput(String signingInput) async => 'signed-proof';
}

class RecordingHardwareBackedDpopPlatform
    with MockPlatformInterfaceMixin
    implements HardwareBackedDpopPlatform {
  int getOrCreateCalls = 0;
  String? lastSigningInput;

  @override
  Future<void> deleteBinding() async {}

  @override
  Future<DpopBindingMaterial?> getExistingBinding() async => null;

  @override
  Future<DpopBindingMaterial> getOrCreateBinding() async {
    getOrCreateCalls += 1;
    return DpopBindingMaterial.fromMap(const {
      'rawPublicKey': 'test-dpop-public-key',
      'jkt': 'test-dpop-jkt',
      'jwk': {
        'kty': 'EC',
        'crv': 'P-256',
        'x': 'test-x',
        'y': 'test-y',
      },
    });
  }

  @override
  Future<DpopBindingMaterial> rotateBinding() => getOrCreateBinding();

  @override
  Future<String> signJwsSigningInput(String signingInput) async {
    lastSigningInput = signingInput;
    return 'signed-proof';
  }
}

Map<String, Object?> _decodeJwtSegment(String segment) {
  final normalized = base64Url.normalize(segment);
  final bytes = base64Url.decode(normalized);
  return Map<String, Object?>.from(jsonDecode(utf8.decode(bytes)) as Map);
}

void main() {
  final HardwareBackedDpopPlatform initialPlatform = HardwareBackedDpopPlatform.instance;

  tearDown(() {
    HardwareBackedDpopPlatform.instance = initialPlatform;
  });

  test('$MethodChannelHardwareBackedDpop is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHardwareBackedDpop>());
  });

  test('DpopBindingMaterial parses a JSON-encoded JWK', () {
    final binding = DpopBindingMaterial.fromMap(const {
      'rawPublicKey': 'test-dpop-public-key',
      'jkt': 'test-dpop-jkt',
      'jwk': '{"kty":"EC","crv":"P-256","x":"test-x","y":"test-y"}',
    });

    expect(binding.rawPublicKey, 'test-dpop-public-key');
    expect(binding.jkt, 'test-dpop-jkt');
    expect(binding.jwk['x'], 'test-x');
  });

  test('buildProof generates a signed DPoP JWT', () async {
    final hardwareBackedDpop = HardwareBackedDpop();
    final fakePlatform = RecordingHardwareBackedDpopPlatform();
    HardwareBackedDpopPlatform.instance = fakePlatform;

    final proof = await hardwareBackedDpop.buildProof(
      htu: 'https://api.example.com/v1/messages',
      htm: 'post',
      accessToken: 'access-token',
      nonce: 'server-nonce',
      issuedAt: DateTime.fromMillisecondsSinceEpoch(1712345678000, isUtc: true),
      jti: 'proof-jti',
    );

    final parts = proof.split('.');
    expect(parts, hasLength(3));
    expect(parts[2], 'signed-proof');
    expect(fakePlatform.getOrCreateCalls, 1);
    expect(fakePlatform.lastSigningInput, '${parts[0]}.${parts[1]}');

    final header = _decodeJwtSegment(parts[0]);
    final payload = _decodeJwtSegment(parts[1]);
    final expectedAth = base64Url
        .encode(sha256.convert(utf8.encode('access-token')).bytes)
        .replaceAll('=', '');

    expect(header['typ'], 'dpop+jwt');
    expect(header['alg'], 'ES256');
    expect(payload['htu'], 'https://api.example.com/v1/messages');
    expect(payload['htm'], 'POST');
    expect(payload['iat'], 1712345678);
    expect(payload['jti'], 'proof-jti');
    expect(payload['nonce'], 'server-nonce');
    expect(payload['ath'], expectedAth);
  });

  test('buildProof rejects overriding reserved claims', () async {
    final hardwareBackedDpop = HardwareBackedDpop();
    final fakePlatform = MockHardwareBackedDpopPlatform();
    HardwareBackedDpopPlatform.instance = fakePlatform;

    await expectLater(
      hardwareBackedDpop.buildProof(
        htu: 'https://api.example.com/v1/messages',
        additionalPayloadClaims: const {'htu': 'override-not-allowed'},
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
