import 'package:test/test.dart';
import 'package:kiss_pocketbase_repository/kiss_pocketbase_repository.dart';

import 'test_helpers.dart';
import '../../../kiss_repository/shared_test_logic/data/product_model.dart';

void main() {
  group('PocketBase ID Validation', () {
    setUpAll(() async {
      await IntegrationTestHelpers.setupIntegrationTests();
    });

    tearDownAll(() async {
      await IntegrationTestHelpers.tearDownIntegrationTests();
    });

    setUp(() async {
      await IntegrationTestHelpers.clearTestCollection();
    });

    group('PocketBaseUtils', () {
      test('should generate valid PocketBase IDs', () {
        final id1 = PocketBaseUtils.generateId();
        final id2 = PocketBaseUtils.generateId();

        // Should be exactly 15 characters
        expect(id1.length, equals(15));
        expect(id2.length, equals(15));

        // Should be different IDs
        expect(id1, isNot(equals(id2)));

        // Should contain only lowercase alphanumeric characters
        expect(RegExp(r'^[a-z0-9]+$').hasMatch(id1), isTrue);
        expect(RegExp(r'^[a-z0-9]+$').hasMatch(id2), isTrue);

        // Should be valid according to our validator
        expect(PocketBaseUtils.isValidId(id1), isTrue);
        expect(PocketBaseUtils.isValidId(id2), isTrue);
      });

      test('should validate ID format correctly', () {
        // Valid IDs
        expect(PocketBaseUtils.isValidId('abc123def456789'), isTrue);
        expect(PocketBaseUtils.isValidId('123456789012345'), isTrue);
        expect(PocketBaseUtils.isValidId('abcdefghijklmno'), isTrue);

        // Invalid IDs - wrong length
        expect(PocketBaseUtils.isValidId(''), isFalse);
        expect(PocketBaseUtils.isValidId('short'), isFalse);
        expect(PocketBaseUtils.isValidId('abc123def45678'), isFalse); // 14 chars
        expect(PocketBaseUtils.isValidId('abc123def4567890'), isFalse); // 16 chars

        // Invalid IDs - wrong characters
        expect(PocketBaseUtils.isValidId('ABC123def456789'), isFalse); // uppercase
        expect(PocketBaseUtils.isValidId('abc123def456789!'), isFalse); // special char
        expect(PocketBaseUtils.isValidId('abc123def456789_'), isFalse); // underscore
        expect(PocketBaseUtils.isValidId('abc123def456789-'), isFalse); // hyphen
        expect(PocketBaseUtils.isValidId('abc123def456 789'), isFalse); // space
      });

      test('should throw exception for invalid IDs', () {
        expect(() => PocketBaseUtils.validateId('invalid'), throwsA(isA<RepositoryException>()));

        expect(() => PocketBaseUtils.validateId('ABC123def456789'), throwsA(isA<RepositoryException>()));

        expect(() => PocketBaseUtils.validateId('abc123def456789!'), throwsA(isA<RepositoryException>()));

        // Should not throw for valid IDs
        expect(() => PocketBaseUtils.validateId('abc123def456789'), returnsNormally);
      });
    });

    group('Repository ID Validation', () {
      test('should reject invalid IDs when adding items', () async {
        final repository = IntegrationTestHelpers.repository;

        final productModel = ProductModel.create(name: 'Sample Product', price: 9.99);

        // Test various invalid ID formats
        final invalidIds = [
          'short', // too short
          'abc123def45678', // 14 chars (too short)
          'abc123def4567890', // 16 chars (too long)
          'ABC123def456789', // uppercase letters
          'abc123def456789!', // special character
          'abc123def456789_', // underscore
          'abc123def456789-', // hyphen
          'abc123def456 789', // space
          '', // empty
        ];

        for (final invalidId in invalidIds) {
          expect(
            () => repository.add(IdentifiedObject(invalidId, productModel.copyWith(id: invalidId))),
            throwsA(isA<RepositoryException>()),
            reason: 'Should reject invalid ID: "$invalidId"',
          );
        }
      });

      test('should accept valid IDs when adding items', () async {
        final repository = IntegrationTestHelpers.repository;

        final productModel = ProductModel.create(name: 'Sample Product', price: 9.99);

        // Test valid ID formats
        final validIds = [
          'abc123def456789',
          '123456789012345',
          'abcdefghijklmno',
          PocketBaseUtils.generateId(),
          PocketBaseUtils.generateId(),
        ];

        for (final validId in validIds) {
          final result = await repository.add(IdentifiedObject(validId, productModel.copyWith(id: validId)));
          expect(result.id, equals(validId));
          expect(result.name, equals('Sample Product'));

          // Clean up for next iteration
          await repository.delete(validId);
        }
      });

      test('should validate IDs in batch operations', () async {
        final repository = IntegrationTestHelpers.repository;

        final productModels = [
          ProductModel.create(name: 'Product 1', price: 9.99),
          ProductModel.create(name: 'Product 2', price: 9.99),
          ProductModel.create(name: 'Product 3', price: 9.99),
        ];

        // Mix of valid and invalid IDs
        final identifiedObjects = [
          IdentifiedObject(
            PocketBaseUtils.generateId(),
            productModels[0].copyWith(id: PocketBaseUtils.generateId()),
          ), // valid
          IdentifiedObject('invalid_id', productModels[1].copyWith(id: 'invalid_id')), // invalid
          IdentifiedObject(
            PocketBaseUtils.generateId(),
            productModels[2].copyWith(id: PocketBaseUtils.generateId()),
          ), // valid
        ];

        // Batch add should fail due to invalid ID
        expect(() => repository.addAll(identifiedObjects), throwsA(isA<RepositoryException>()));

        // Verify no objects were created (all-or-nothing behavior)
        expect(() => repository.get(identifiedObjects[0].id), throwsA(isA<RepositoryException>()));
        expect(() => repository.get(identifiedObjects[2].id), throwsA(isA<RepositoryException>()));
      });

      test('should handle edge cases in ID validation', () async {
        final repository = IntegrationTestHelpers.repository;

        final productModel = ProductModel.create(name: 'Sample Product', price: 9.99);

        // Test edge cases
        final edgeCaseIds = [
          '000000000000000', // all zeros (valid)
          'zzzzzzzzzzzzzzz', // all z's (valid)
          '999999999999999', // all 9's (valid)
          'aaaaaaaaaaaaaaa', // all a's (valid)
        ];

        for (final edgeId in edgeCaseIds) {
          final result = await repository.add(IdentifiedObject(edgeId, productModel.copyWith(id: edgeId)));
          expect(result.id, equals(edgeId));

          // Clean up
          await repository.delete(edgeId);
        }
      });
    });
  });
}
