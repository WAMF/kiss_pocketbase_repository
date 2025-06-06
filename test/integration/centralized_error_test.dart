import 'package:test/test.dart';

import 'test_helpers.dart';
import '../../../kiss_repository/test/integration/basic_error_integration_test.dart';

void main() {
  group('PocketBase Repository - Centralized Error Tests', () {
    setUpAll(() async {
      await IntegrationTestHelpers.setupIntegrationTests();
    });

    tearDownAll(() async {
      await IntegrationTestHelpers.tearDownIntegrationTests();
    });

    setUp(() async {
      await IntegrationTestHelpers.clearTestCollection();
    });

    group('Error Handling Tests', () {
      // Run the centralized error tests
      runBasicErrorTests(() => IntegrationTestHelpers.repository);
    });
  });
}
