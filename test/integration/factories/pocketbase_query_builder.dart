import 'package:kiss_repository/kiss_repository.dart';
import 'package:kiss_repository_tests/kiss_repository_tests.dart';
import 'package:pocketbase/pocketbase.dart';

/// PocketBase-specific query builder for ProductModel
/// Uses PocketBase filter syntax: https://pocketbase.io/docs/api-rules-and-filters/
///
/// Every value is bound through a [PocketBase.filter] placeholder (`{:name}`).
/// No value is interpolated into the filter string. `filter` quotes a string
/// value and escapes a single quote inside it, so the value cannot close its
/// own literal and append filter syntax. `filter` emits a number unquoted.
///
/// Copy this pattern, not string interpolation, when you write a query builder
/// of your own. The rule holds for a numeric field as well: a numeric field can
/// become a string field later, and an interpolated string field is injectable.
class TestPocketBaseProductQueryBuilder implements QueryBuilder<String> {
  TestPocketBaseProductQueryBuilder(this._client);

  final PocketBase _client;

  @override
  String build(Query query) {
    if (query is QueryByName) {
      // PocketBase uses ~ operator for "contains/like" matching
      return _client.filter(
        'name ~ {:namePrefix}',
        <String, dynamic>{'namePrefix': query.namePrefix},
      );
    }

    if (query is QueryByPriceRange) {
      final conditions = <String>[];
      if (query.minPrice != null) {
        conditions.add(
          _client.filter(
            'price >= {:minPrice}',
            <String, dynamic>{'minPrice': query.minPrice},
          ),
        );
      }
      if (query.maxPrice != null) {
        conditions.add(
          _client.filter(
            'price <= {:maxPrice}',
            <String, dynamic>{'maxPrice': query.maxPrice},
          ),
        );
      }
      return conditions.join(' && ');
    }

    throw UnsupportedError(
      'TestPocketBaseProductQueryBuilder: unsupported query type '
      '${query.runtimeType}',
    );
  }
}
