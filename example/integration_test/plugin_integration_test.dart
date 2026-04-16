// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:hardware_backed_dpop/hardware_backed_dpop.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getOrCreateBinding returns public material', (
    WidgetTester tester,
  ) async {
    final HardwareBackedDpop plugin = HardwareBackedDpop();
    final binding = await plugin.getOrCreateBinding();

    expect(binding.rawPublicKey, isNotEmpty);
    expect(binding.jkt, isNotEmpty);
    expect(binding.jwk['kty'], 'EC');
  });
}
