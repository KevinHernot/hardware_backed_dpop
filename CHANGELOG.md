# Changelog

## 0.1.1

- add `DpopNonceHandler` and `DpopNonceChallenge` helpers for RFC 9449 `use_dpop_nonce` challenge parsing
- add case-insensitive metadata parsing utilities for `dpop-nonce` and `www-authenticate`
- add unit tests and documentation for nonce retry flow integration

## 0.1.0

- initial public release of hardware-backed DPoP binding and proof-signing primitives
- Android Keystore and iOS Secure Enclave / Keychain-backed ES256 bindings
- DPoP binding export as raw public key, JWK, and thumbprint
- proof-building helper with `ath`, `nonce`, and custom payload claims support
