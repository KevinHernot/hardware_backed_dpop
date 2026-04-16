import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_backed_dpop/hardware_backed_dpop_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelHardwareBackedDpop platform = MethodChannelHardwareBackedDpop();
  const MethodChannel channel = MethodChannel('hardware_backed_dpop');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getOrCreateBinding':
              return <String, Object?>{
                'rawPublicKey': 'test-dpop-public-key',
                'jkt': 'test-dpop-jkt',
                'jwk': <String, String>{
                  'kty': 'EC',
                  'crv': 'P-256',
                  'x': 'test-x',
                  'y': 'test-y',
                },
              };
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getOrCreateBinding', () async {
    final binding = await platform.getOrCreateBinding();

    expect(binding.rawPublicKey, 'test-dpop-public-key');
    expect(binding.jkt, 'test-dpop-jkt');
    expect(binding.jwk['x'], 'test-x');
  });
}
