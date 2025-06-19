import 'package:kiss_repository_tests/kiss_repository_tests.dart';
import 'package:test/test.dart';

import 'factories/pocketbase_repository_factory.dart';

void main() {
  setUpAll(() async {
    await PocketBaseRepositoryFactory.initialize();
  });

  runRepositoryTests(
    implementationName: 'PocketBase',
    factoryProvider: PocketBaseRepositoryFactory.new,
    cleanup: () {},
  );
}
