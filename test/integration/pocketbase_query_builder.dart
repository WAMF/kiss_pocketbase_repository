import 'package:kiss_repository/kiss_repository.dart';

import '../../../kiss_repository/shared_test_logic/data/queries.dart';

/// PocketBase-specific query builder for ProductModel
/// Uses PocketBase filter syntax: https://pocketbase.io/docs/api-rules-and-filters/
class TestPocketBaseProductQueryBuilder implements QueryBuilder<String> {
  @override
  String build(Query query) {
    if (query is QueryByName) {
      // PocketBase uses ~ operator for "contains/like" matching
      return 'name ~ "${query.namePrefix}"';
    }

    if (query is QueryByCreatedAfter) {
      return 'created >= "${query.date.toIso8601String()}"';
    }

    if (query is QueryByCreatedBefore) {
      return 'created <= "${query.date.toIso8601String()}"';
    }

    if (query is QueryByPriceGreaterThan) {
      return 'price > ${query.price}';
    }

    if (query is QueryByPriceLessThan) {
      return 'price < ${query.price}';
    }

    return '';
  }
}
