import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_rar_example/rar_checks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flutter_rar handles a password-protected RAR5 archive', (tester) async {
    final results = await runRarChecks();
    for (final check in results) {
      expect(check.passed, isTrue, reason: '${check.name}: ${check.detail}');
    }
  });
}
