import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hardware_backed_dpop_platform_interface.dart';
import 'src/dpop_binding_material.dart';

/// An implementation of [HardwareBackedDpopPlatform] that uses method channels.
class MethodChannelHardwareBackedDpop extends HardwareBackedDpopPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('hardware_backed_dpop');

  @override
  Future<DpopBindingMaterial> rotateBinding() async {
    await deleteBinding();
    return getOrCreateBinding();
  }

  @override
  Future<DpopBindingMaterial> getOrCreateBinding() async {
    final result = await methodChannel.invokeMethod<dynamic>('getOrCreateBinding');
    if (result is! Map) {
      throw PlatformException(
        code: 'INVALID_DPOP_BINDING',
        message: 'Native platform returned an invalid DPoP binding payload.',
      );
    }
    return DpopBindingMaterial.fromMap(Map<Object?, Object?>.from(result));
  }

  @override
  Future<DpopBindingMaterial?> getExistingBinding() async {
    final result = await methodChannel.invokeMethod<dynamic>('getExistingBinding');
    if (result == null) {
      return null;
    }
    if (result is! Map) {
      throw PlatformException(
        code: 'INVALID_DPOP_BINDING',
        message: 'Native platform returned an invalid existing DPoP binding.',
      );
    }
    return DpopBindingMaterial.fromMap(Map<Object?, Object?>.from(result));
  }

  @override
  Future<String> signJwsSigningInput(String signingInput) async {
    if (signingInput.isEmpty) {
      throw ArgumentError.value(
        signingInput,
        'signingInput',
        'must not be empty',
      );
    }

    final signature = await methodChannel.invokeMethod<String>(
      'signJwsSigningInput',
      {'signingInput': signingInput},
    );
    if (signature == null || signature.isEmpty) {
      throw PlatformException(
        code: 'INVALID_DPOP_SIGNATURE',
        message: 'Native platform returned an empty DPoP signature.',
      );
    }
    return signature;
  }

  @override
  Future<void> deleteBinding() {
    return methodChannel.invokeMethod<void>('deleteBinding');
  }
}
