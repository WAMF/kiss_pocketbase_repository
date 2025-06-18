import 'package:kiss_repository/testing.dart';
import 'package:test/test.dart';

import 'model/pocketbase_repository_factory.dart';

void main() {
  setUpAll(() async {
    await PocketBaseRepositoryFactory.initialize();
  });

  final factory = PocketBaseRepositoryFactory();
  final tester = RepositoryTester('PocketBase', factory, () {});

  // ignore: cascade_invocations
  tester.run();
}
