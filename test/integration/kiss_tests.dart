import 'package:test/test.dart';

import 'test_helpers.dart';
import '../../../kiss_repository/test/integration/basic_crud_integration_test.dart';
import '../../../kiss_repository/test/integration/basic_batch_integration_test.dart';
import '../../../kiss_repository/test/integration/basic_query_integration_test.dart';
import '../../../kiss_repository/test/integration/basic_streaming_integration_test.dart';
import '../../../kiss_repository/test/integration/basic_error_integration_test.dart';

void main() {
  setUpAll(() async {
    await IntegrationTestHelpers.setupIntegrationTests();
  });

  tearDownAll(() async {
    await IntegrationTestHelpers.tearDownIntegrationTests();
  });

  setUp(() async {
    await IntegrationTestHelpers.clearTestCollection();
  });

  group('PocketBase Repository - Centralized CRUD Tests', () {
    runBasicCrudTests(() => IntegrationTestHelpers.repository);
  });

  group('Batch Operations Tests', () {
    runBasicBatchTests(() => IntegrationTestHelpers.repository);
  });

  group('Query Filtering Tests', () {
    runBasicQueryTests(() => IntegrationTestHelpers.repository);
  });

  group('Streaming Tests', () {
    runBasicStreamingTests(() => IntegrationTestHelpers.repository);
  });

  group('Error Handling Tests', () {
    runBasicErrorTests(() => IntegrationTestHelpers.repository);
  });
}
