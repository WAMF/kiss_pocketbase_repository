import 'package:pocketbase/pocketbase.dart';
import 'package:kiss_pocketbase_repository/kiss_pocketbase_repository.dart';

import '../../../kiss_repository/shared_test_logic/data/product_model.dart';
import 'pocketbase_query_builder.dart';

class IntegrationTestHelpers {
  static late PocketBase pocketbaseClient;
  static late RepositoryPocketBase<ProductModel> repository;
  static const String testCollection = 'products';
  static const String pocketbaseUrl = 'http://localhost:8090';

  static const String testUserEmail = 'testuser@example.com';
  static const String testUserPassword = 'testuser123';

  static Future<void> initializePocketBase() async {
    pocketbaseClient = PocketBase(pocketbaseUrl);

    try {
      await pocketbaseClient.collection('users').authWithPassword(testUserEmail, testUserPassword);
      print('🔐 Authenticated as test user: $testUserEmail');
    } catch (e) {
      throw Exception(
        'Failed to authenticate test user. Make sure user exists:\n'
        'Email: $testUserEmail\n'
        'Error: $e',
      );
    }

    repository = RepositoryPocketBase<ProductModel>(
      client: pocketbaseClient,
      collection: testCollection,
      fromPocketBase: (record) => ProductModel(
        id: record.id,
        name: record.data['name'] as String,
        price: (record.data['price'] as num).toDouble(),
        description: record.data['description'] as String? ?? '',
        created: DateTime.parse(record.data['created'] as String),
      ),
      toPocketBase: (productModel) => {
        'name': productModel.name,
        'price': productModel.price,
        'description': productModel.description,
        'created': productModel.created.toIso8601String(),
      },
      queryBuilder: ProductModelQueryBuilder(),
    );
  }

  static Future<void> clearTestCollection() async {
    try {
      final records = await pocketbaseClient.collection(testCollection).getFullList();

      for (final record in records) {
        await pocketbaseClient.collection(testCollection).delete(record.id);
      }

      if (records.isNotEmpty) {
        print('🧹 Cleared ${records.length} test records');
      }
    } catch (e) {
      print('ℹ️ Collection clear: $e');
    }
  }

  static Future<void> setupIntegrationTests() async {
    await initializePocketBase();

    try {
      await pocketbaseClient.health.check();
      print('✅ Connected to PocketBase at $pocketbaseUrl');
    } catch (e) {
      throw Exception(
        'Failed to connect to PocketBase. Make sure it\'s running at $pocketbaseUrl\n'
        'Run: ./scripts/setup_test_collection_and_user.sh\n'
        'Error: $e',
      );
    }

    print('🎯 Integration tests ready to run');
  }

  static Future<void> tearDownIntegrationTests() async {
    try {
      await clearTestCollection();
      print('✅ Integration test cleanup completed');
    } catch (e) {
      print('ℹ️ Cleanup error (may be harmless): $e');
    }
  }
}
