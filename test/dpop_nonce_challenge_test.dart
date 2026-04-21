import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_backed_dpop/hardware_backed_dpop.dart';

void main() {
  group('DpopNonceHandler', () {
    test('captures nonce from case-insensitive metadata', () {
      final handler = DpopNonceHandler();

      final nonce = handler.captureNonceFromMetadata(const {
        'DPoP-Nonce': ' nonce-1 ',
      });

      expect(nonce, 'nonce-1');
      expect(handler.currentNonce, 'nonce-1');
    });

    test('extracts nonce challenge from structured error code', () {
      final handler = DpopNonceHandler();

      final challenge = handler.extractChallenge(
        metadata: const {'dpop-nonce': 'nonce-2'},
        errorCode: 'USE_DPOP_NONCE',
      );

      expect(challenge, isNotNull);
      expect(challenge!.nonce, 'nonce-2');
      expect(handler.currentNonce, 'nonce-2');
    });

    test('extracts nonce challenge from WWW-Authenticate header', () {
      final handler = DpopNonceHandler();

      final challenge = handler.extractChallenge(
        metadata: const {
          'www-authenticate': 'DPoP error="use_dpop_nonce"',
          'dpop-nonce': 'nonce-3',
        },
      );

      expect(challenge, isNotNull);
      expect(challenge!.nonce, 'nonce-3');
      expect(challenge.wwwAuthenticate, 'DPoP error="use_dpop_nonce"');
    });

    test('returns null when challenge signal is missing', () {
      final handler = DpopNonceHandler();

      final challenge = handler.extractChallenge(
        metadata: const {'dpop-nonce': 'nonce-4'},
        errorCode: 'INVALID_DPOP_PROOF',
      );

      expect(challenge, isNull);
      expect(handler.currentNonce, isNull);
    });

    test('parses iterable metadata values case-insensitively', () {
      final value = DpopNonceHandler.metadataValueCaseInsensitive(
        const {
          'DPOP-NONCE': <String>['', 'nonce-5'],
        },
        'dpop-nonce',
      );

      expect(value, 'nonce-5');
    });

    test('detects use_dpop_nonce challenge from details payload', () {
      final challenge = DpopNonceHandler.isUseDpopNonceChallenge(
        details: const {'reason': 'use_dpop_nonce'},
      );

      expect(challenge, isTrue);
    });
  });
}
