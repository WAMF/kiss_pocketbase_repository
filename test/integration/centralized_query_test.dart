import 'package:test/test.dart';

import 'test_helpers.dart';
import '../../../kiss_repository/test/integration/basic_query_integration_test.dart';

void main() {
  group('PocketBase Repository - Centralized Query Tests', () {
    setUpAll(() async {
      await IntegrationTestHelpers.setupIntegrationTests();
    });

    tearDownAll(() async {
      await IntegrationTestHelpers.tearDownIntegrationTests();
    });

    setUp(() async {
      await IntegrationTestHelpers.clearTestCollection();
    });

    group('Query Filtering Tests', () {
      // Run the centralized query tests
      runBasicQueryTests(() => IntegrationTestHelpers.repository);
    });
  });
}
