# Extraction Plan

This package intentionally starts small.

## Current Scope

- hardware-backed ES256 binding generation on Android and iOS
- public binding export for backend registration
- native JWS signing for DPoP proofs
- a thin Dart proof builder for app integration

## Likely Next Extractions

- nonce challenge helpers for automatic retry flows
- a backend verification reference implementation
- a small request interceptor package for HTTP / gRPC clients
- optional key-attestation support where platform guarantees make it practical