import 'package:test/test.dart';
import 'package:kiss_repository/testing.dart';

import 'model/pocketbase_repository_factory.dart';

void main() {
  // Initialize factory before all tests
  setUpAll(() async {
    await PocketBaseRepositoryFactory.initialize();
  });

  final factory = PocketBaseRepositoryFactory();
  final tester = RepositoryTester('PocketBase', factory, () {
    // Cleanup function - will be called after each test group
  });

  tester.run();
}
