import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hardware_backed_dpop_example/main.dart';

const _channel = MethodChannel('hardware_backed_dpop');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getOrCreateBinding':
            case 'getExistingBinding':
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
            case 'signJwsSigningInput':
              return 'signed-proof';
            case 'deleteBinding':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('shows the DPoP demo screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('hardware_backed_dpop example'), findsOneWidget);
    expect(
      find.text('Hardware-backed DPoP binding + proof signing demo'),
      findsOneWidget,
    );
    expect(find.text('Binding material'), findsOneWidget);
  });
}
