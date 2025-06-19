import 'package:kiss_repository_tests/kiss_repository_tests.dart';
import 'package:test/test.dart';

import 'factories/pocketbase_repository_factory.dart';

void main() {
  late PocketBaseRepositoryFactory factory;

  setUpAll(() async {
    await PocketBaseRepositoryFactory.initialize();
    factory = PocketBaseRepositoryFactory();
  });

  tearDownAll(() async {
    factory.dispose();
  });

  setUp(() async {
    await factory.cleanup();
  });

  group('PocketBase-Specific Behavior', () {
    test('addAutoIdentified without updateObjectWithId returns object with server-generated ID', () async {
      final repository = factory.createRepository();
      final productModel = ProductModel.create(name: 'ProductX', price: 9.99);

      final addedObject = await repository.addAutoIdentified(productModel);

      expect(addedObject.id, isNotEmpty);
      expect(addedObject.name, equals('ProductX'));
      expect(addedObject.price, equals(9.99));

      // Verify the object was actually saved and can be retrieved
      final retrieved = await repository.get(addedObject.id);
      expect(retrieved.id, equals(addedObject.id));
      expect(retrieved.name, equals('ProductX'));

      // Note: PocketBase always returns the complete object with server-generated ID
      // because it's a SQL-based system where the ID is part of the record structure
    });
  });
}
