# API Overview

## Core Types

### `HardwareBackedDpop`

- `getOrCreateBinding()` returns the current ES256 binding or creates one
- `getExistingBinding()` returns the binding if it already exists
- `rotateBinding()` deletes the current binding and creates a new one
- `signJwsSigningInput(signingInput)` signs a precomputed JWS input with the native key
- `buildProof(...)` builds and signs a DPoP proof JWT
- `deleteBinding()` deletes the current native key material

### `DpopBindingMaterial`

- `rawPublicKey`: base64url-encoded uncompressed P-256 public key
- `jkt`: RFC 7638 JWK thumbprint for server-side binding lookup
- `jwk`: public JWK map suitable for the DPoP JWT header

## Proof Builder Notes

`buildProof(...)` accepts:

- `htu`: request target to bind
- `htm`: request method, defaulting to `POST`
- `accessToken`: optional bearer token used to populate the `ath` claim
- `nonce`: optional server-provided DPoP nonce
- `jti`: optional proof ID override
- `issuedAt`: optional timestamp override for deterministic tests
- `additionalPayloadClaims`: optional non-reserved claims to append

Reserved claims (`iat`, `jti`, `htm`, `htu`, `ath`, `nonce`) are intentionally protected and cannot be overridden through `additionalPayloadClaims`.