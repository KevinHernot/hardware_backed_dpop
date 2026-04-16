# hardware_backed_dpop

[![CI](https://github.com/KevinHernot/hardware_backed_dpop/actions/workflows/ci.yml/badge.svg)](https://github.com/KevinHernot/hardware_backed_dpop/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/tag/KevinHernot/hardware_backed_dpop?label=release)](https://github.com/KevinHernot/hardware_backed_dpop/releases)

Hardware-backed DPoP binding and proof-signing primitives for Flutter apps.

`hardware_backed_dpop` is a Flutter package for hardware-backed DPoP bindings and proof signing. It focuses on one narrow but high-value job: minting a stable ES256 DPoP binding in the platform keystore, exposing the public binding material needed by the backend, and signing JWS inputs without exporting the private key.

## Status

Experimental, but real and usable.

## What Is Included Today

- Android Keystore-backed P-256 binding generation with StrongBox fallback when available
- iOS Secure Enclave-backed P-256 binding generation with secure Keychain fallback
- public binding export as raw public key, JWK, and RFC 7638 thumbprint (`jkt`)
- JWS signing through the platform keystore so the private key never leaves native storage
- a Dart helper for building DPoP proofs with `ath` and `nonce` support

## Quick Start

```dart
import 'package:hardware_backed_dpop/hardware_backed_dpop.dart';

final dpop = HardwareBackedDpop();

final binding = await dpop.getOrCreateBinding();
print('DPoP thumbprint: ${binding.jkt}');

final proof = await dpop.buildProof(
  htu: 'https://api.example.com/v1/messages',
  htm: 'POST',
  accessToken: accessToken,
  nonce: nonceFromServer,
);

print(proof);
```

## Full-Stack Integration Notes

This package covers the **client-side possession** half of the flow.

Typical integration looks like this:

1. the app creates a hardware-backed binding and sends `binding.jkt` during sign-in or device registration
2. the backend stores that thumbprint in `cnf.jkt` or another device-binding record
3. each protected request carries a DPoP proof signed by the same private key
4. the backend verifies the signature, nonce, replay constraints, and request binding

If your server binds proofs more tightly than standard RFC 9449 URL matching—for example to a gRPC method path—you can still pass that target through `htu` as long as both sides agree on the contract.

## Package Focus

This package intentionally ships the mobile-side key and signing primitive, not an opinionated auth client.

The next extraction candidates are documented in [docs/EXTRACTION_PLAN.md](docs/EXTRACTION_PLAN.md).

## Development

```bash
flutter test
```

## Examples

- [example](example)
- [docs/API.md](docs/API.md)

## License

Released under the [MIT](LICENSE) license.

