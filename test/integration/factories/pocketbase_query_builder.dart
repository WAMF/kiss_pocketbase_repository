import 'package:kiss_repository/kiss_repository.dart';
import 'package:kiss_repository_tests/test.dart';

/// PocketBase-specific query builder for ProductModel
/// Uses PocketBase filter syntax: https://pocketbase.io/docs/api-rules-and-filters/
class TestPocketBaseProductQueryBuilder implements QueryBuilder<String> {
  @override
  String build(Query query) {
    if (query is QueryByName) {
      // PocketBase uses ~ operator for "contains/like" matching
      final escaped = _escapePocketBaseFilterString(query.namePrefix);
      return 'name ~ "$escaped"';
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

    throw UnsupportedError('ProductModelQueryBuilder: unsupported query type \\${query.runtimeType}');
  }
}

String _escapePocketBaseFilterString(String input) {
  return input.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}
