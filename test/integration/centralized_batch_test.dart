import 'package:test/test.dart';

import 'test_helpers.dart';
import '../../../kiss_repository/test/integration/basic_batch_integration_test.dart';

void main() {
  group('PocketBase Repository - Centralized Batch Tests', () {
    setUpAll(() async {
      await IntegrationTestHelpers.setupIntegrationTests();
    });

    tearDownAll(() async {
      await IntegrationTestHelpers.tearDownIntegrationTests();
    });

    setUp(() async {
      await IntegrationTestHelpers.clearTestCollection();
    });

    group('Batch Operations Tests', () {
      // Run the centralized batch tests
      runBasicBatchTests(() => IntegrationTestHelpers.repository);
    });
  });
}
