import 'package:kiss_repository_tests/kiss_repository_tests.dart';

import 'factories/pocketbase_repository_factory.dart';

void main() {
  runRepositoryTests(
    implementationName: 'PocketBase',
    factoryProvider: PocketBaseRepositoryFactory.new,
    cleanup: () {},
  );
}
