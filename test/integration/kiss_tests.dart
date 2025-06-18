import 'package:kiss_repository_tests/test.dart';
import 'package:test/test.dart';

import 'factories/pocketbase_repository_factory.dart';

void main() {
  setUpAll(() async {
    await PocketBaseRepositoryFactory.initialize();
  });

  final factory = PocketBaseRepositoryFactory();
  final tester = RepositoryTester('PocketBase', factory, () {});

  // ignore: cascade_invocations
  tester.run();
}
