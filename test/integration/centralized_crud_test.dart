import 'package:test/test.dart';

import 'test_helpers.dart';
import '../../../kiss_repository/test/integration/basic_crud_integration_test.dart';

void main() {
  group('PocketBase Repository - Centralized CRUD Tests', () {
    setUpAll(() async {
      await IntegrationTestHelpers.setupIntegrationTests();
    });

    tearDownAll(() async {
      await IntegrationTestHelpers.tearDownIntegrationTests();
    });

    setUp(() async {
      await IntegrationTestHelpers.clearTestCollection();
    });

    group('Basic CRUD Tests', () {
      // Run the centralized CRUD tests
      runBasicCrudTests(() => IntegrationTestHelpers.repository);
    });
  });
}
