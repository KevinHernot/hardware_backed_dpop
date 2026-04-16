import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hardware_backed_dpop_method_channel.dart';
import 'src/dpop_binding_material.dart';

abstract class HardwareBackedDpopPlatform extends PlatformInterface {
  /// Constructs a HardwareBackedDpopPlatform.
  HardwareBackedDpopPlatform() : super(token: _token);

  static final Object _token = Object();

  static HardwareBackedDpopPlatform _instance = MethodChannelHardwareBackedDpop();

  /// The default instance of [HardwareBackedDpopPlatform] to use.
  ///
  /// Defaults to [MethodChannelHardwareBackedDpop].
  static HardwareBackedDpopPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HardwareBackedDpopPlatform] when
  /// they register themselves.
  static set instance(HardwareBackedDpopPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<DpopBindingMaterial> rotateBinding() {
    throw UnimplementedError('rotateBinding() has not been implemented.');
  }

  Future<DpopBindingMaterial> getOrCreateBinding() {
    throw UnimplementedError('getOrCreateBinding() has not been implemented.');
  }

  Future<DpopBindingMaterial?> getExistingBinding() {
    throw UnimplementedError('getExistingBinding() has not been implemented.');
  }

  Future<String> signJwsSigningInput(String signingInput) {
    throw UnimplementedError(
      'signJwsSigningInput() has not been implemented.',
    );
  }

  Future<void> deleteBinding() {
    throw UnimplementedError('deleteBinding() has not been implemented.');
  }
}
