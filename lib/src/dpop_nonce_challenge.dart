class DpopNonceChallenge {
  const DpopNonceChallenge({
    required this.nonce,
    this.wwwAuthenticate,
  });

  final String nonce;
  final String? wwwAuthenticate;
}

/// Helper for RFC 9449 nonce challenge handling.
///
/// This class keeps the latest nonce and provides case-insensitive metadata
/// parsing that works across HTTP-style headers and gRPC-style metadata maps.
class DpopNonceHandler {
  String? _currentNonce;

  String? get currentNonce => _currentNonce;

  void clear() {
    _currentNonce = null;
  }

  void setCurrentNonce(String? nonce) {
    _currentNonce = _normalizedValue(nonce);
  }

  /// Captures and stores `dpop-nonce` from metadata.
  String? captureNonceFromMetadata(Map<String, Object?> metadata) {
    final nonce = metadataValueCaseInsensitive(metadata, 'dpop-nonce');
    if (nonce != null) {
      _currentNonce = nonce;
    }
    return _currentNonce;
  }

  /// Returns a parsed nonce challenge when the payload signals
  /// `use_dpop_nonce` and includes a `dpop-nonce` value.
  DpopNonceChallenge? extractChallenge({
    Map<String, Object?> metadata = const {},
    String? errorCode,
    String? errorMessage,
    Map<String, Object?> details = const {},
  }) {
    final nonce = metadataValueCaseInsensitive(metadata, 'dpop-nonce') ??
        metadataValueCaseInsensitive(details, 'dpop-nonce');
    final wwwAuthenticate =
        metadataValueCaseInsensitive(metadata, 'www-authenticate') ??
            metadataValueCaseInsensitive(details, 'www-authenticate');

    final challenge = isUseDpopNonceChallenge(
      errorCode: errorCode,
      errorMessage: errorMessage,
      wwwAuthenticate: wwwAuthenticate,
      details: details,
    );
    if (!challenge || nonce == null) {
      return null;
    }

    _currentNonce = nonce;
    return DpopNonceChallenge(
      nonce: nonce,
      wwwAuthenticate: wwwAuthenticate,
    );
  }

  static bool isUseDpopNonceChallenge({
    String? errorCode,
    String? errorMessage,
    String? wwwAuthenticate,
    Map<String, Object?> details = const {},
  }) {
    if (_containsUseDpopNonce(errorCode) ||
        _containsUseDpopNonce(errorMessage) ||
        _containsUseDpopNonce(wwwAuthenticate)) {
      return true;
    }

    for (final value in details.values) {
      if (_containsUseDpopNonce(_stringValue(value))) {
        return true;
      }
      if (value is Iterable<Object?>) {
        for (final item in value) {
          if (_containsUseDpopNonce(_stringValue(item))) {
            return true;
          }
        }
      }
    }

    return false;
  }

  static String? metadataValueCaseInsensitive(
    Map<String, Object?> metadata,
    String key,
  ) {
    if (metadata.isEmpty || key.isEmpty) {
      return null;
    }
    final normalizedKey = key.toLowerCase();
    for (final entry in metadata.entries) {
      if (entry.key.toLowerCase() != normalizedKey) {
        continue;
      }

      if (entry.value is Iterable<Object?>) {
        for (final item in entry.value as Iterable<Object?>) {
          final candidate = _normalizedValue(_stringValue(item));
          if (candidate != null) {
            return candidate;
          }
        }
      }

      final directValue = _normalizedValue(_stringValue(entry.value));
      if (directValue != null) {
        return directValue;
      }
    }

    return null;
  }

  static String? _stringValue(Object? value) {
    if (value == null) {
      return null;
    }
    return value.toString();
  }

  static String? _normalizedValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static bool _containsUseDpopNonce(String? value) {
    final normalized = _normalizedValue(value)?.toLowerCase();
    if (normalized == null) {
      return false;
    }

    if (normalized == 'use_dpop_nonce' || normalized == 'use-dpop-nonce') {
      return true;
    }

    return normalized.contains('use_dpop_nonce') ||
        normalized.contains('use-dpop-nonce');
  }
}
