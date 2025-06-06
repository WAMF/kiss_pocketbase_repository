import 'package:kiss_pocketbase_repository/kiss_pocketbase_repository.dart';

// Import contract tests using path import
import '../../kiss_repository/test/src/contract/repository_contract_tests.dart';
import '../../kiss_repository/test/src/contract/test_data.dart';

import 'integration/test_helpers.dart';

/// QueryBuilder for TestObject - needed for PocketBase repository
class TestObjectQueryBuilder implements QueryBuilder<String> {
  @override
  String build(Query query) {
    // For basic contract tests, we just need to support AllQuery
    return ''; // Empty filter returns all records
  }
}

void main() {
  // Run the contract tests using Pocketbase implementation with TestObject
  runRepositoryContractTestsWithTestObject(
    'Pocketbase Repository Contract Tests - POC',
    () => RepositoryPocketBase<TestObject>(
        client: IntegrationTestHelpers.pocketbaseClient,
        collection: 'test_objects', // Use a different collection for contract tests
        fromPocketBase: (record) => TestObject(id: record.id, name: record.data['name'] as String),
        toPocketBase: (testObject) => {'name': testObject.name},
        queryBuilder: TestObjectQueryBuilder(),
      ),
    setUp: () async {
      // Clear the test_objects collection before each test
      try {
        final records = await IntegrationTestHelpers.pocketbaseClient.collection('test_objects').getFullList();

        for (final record in records) {
          await IntegrationTestHelpers.pocketbaseClient.collection('test_objects').delete(record.id);
        }

        if (records.isNotEmpty) {
          print('🧹 Cleared ${records.length} test object records');
        }
      } catch (e) {
        print('ℹ️ Test object collection clear: $e');
      }
    },
    setUpAll: () async {
      await IntegrationTestHelpers.initializePocketBase();

      print('🚀 Setting up Pocketbase contract tests with TestObject...');
    },
    tearDownAll: () async {
      print('🏁 Pocketbase contract tests completed');
    },
  );
}
