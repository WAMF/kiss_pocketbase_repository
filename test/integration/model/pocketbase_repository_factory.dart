// ignore_for_file: avoid_print

import 'package:kiss_pocketbase_repository/kiss_pocketbase_repository.dart';
import 'package:kiss_repository/test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'pocketbase_query_builder.dart';

class PocketBaseRepositoryFactory implements RepositoryFactory {
  static late PocketBase _pocketbaseClient;
  static bool _initialized = false;

  Repository<ProductModel>? _repository;

  static const String _testCollection = 'products';
  static const String _testUserEmail = 'testuser@example.com';
  static const String _testUserPassword = 'testuser123';

  static Future<void> initialize() async {
    if (_initialized) return;

    _pocketbaseClient = PocketBase('http://127.0.0.1:8090');

    // Test connection
    try {
      await _pocketbaseClient.health.check();
      print('✅ PocketBase connection established');
    } catch (e) {
      throw Exception('❌ Failed to connect to PocketBase: $e');
    }

    // Authenticate with test user
    try {
      await _pocketbaseClient.collection('users').authWithPassword(_testUserEmail, _testUserPassword);
      print('🔐 Authenticated as test user: $_testUserEmail');
    } catch (e) {
      throw Exception('❌ Failed to authenticate test user: $e');
    }

    _initialized = true;
  }

  @override
  Repository<ProductModel> createRepository() {
    if (!_initialized) {
      throw StateError('Factory not initialized. Call initialize() first.');
    }

    _repository = RepositoryPocketBase<ProductModel>(
      client: _pocketbaseClient,
      collection: _testCollection,
      queryBuilder: TestPocketBaseProductQueryBuilder(),
      fromPocketBase: (record) => ProductModel(
        id: record.data['id'] as String? ?? '',
        name: record.data['name'] as String,
        price: (record.data['price'] as num).toDouble(),
        description: record.data['description'] as String? ?? '',
        created: DateTime.parse(record.data['created'] as String),
      ),
      toPocketBase: (productModel) => {
        'id': productModel.id,
        'name': productModel.name,
        'price': productModel.price,
        'description': productModel.description,
        'created': productModel.created.toIso8601String(),
      },
    );
    return _repository!;
  }

  @override
  Future<void> cleanup() async {
    if (_repository == null) {
      print('🧹 Cleanup: No repository to clean');
      return;
    }

    try {
      final records = await _pocketbaseClient.collection(_testCollection).getFullList();
      print('🧹 Cleanup: Found ${records.length} items to delete');

      if (records.isNotEmpty) {
        for (final record in records) {
          await _pocketbaseClient.collection(_testCollection).delete(record.id);
        }
        print('🧹 Cleanup: Deleted ${records.length} items successfully');
      } else {
        print('🧹 Cleanup: Collection already empty');
      }
    } catch (e) {
      print('❌ Cleanup failed: $e');
    }
  }

  @override
  void dispose() {
    // No resources to dispose for PocketBase
    _repository = null;
    _initialized = false;
  }
}
