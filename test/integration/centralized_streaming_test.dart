import 'package:test/test.dart';

import 'test_helpers.dart';
import '../../../kiss_repository/test/integration/basic_streaming_integration_test.dart';

void main() {
  group('PocketBase Repository - Centralized Streaming Tests', () {
    setUpAll(() async {
      await IntegrationTestHelpers.setupIntegrationTests();
    });

    tearDownAll(() async {
      await IntegrationTestHelpers.tearDownIntegrationTests();
    });

    setUp(() async {
      await IntegrationTestHelpers.clearTestCollection();
    });

    group('Streaming Operations Tests', () {
      // Run the centralized streaming tests
      runBasicStreamingTests(() => IntegrationTestHelpers.repository);
    });
  });
}
