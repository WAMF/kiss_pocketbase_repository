import 'package:test/test.dart';

import 'id_validation_test.dart' as id_validation_tests;
import 'kiss_tests.dart' as kiss_tests;
import 'pocketbase_specific_tests.dart' as pocketbase_specific_tests;

void main() {
  group('All PocketBase Integration Tests', () {
    // KISS Repository Tests using Factory Pattern
    group('KISS Repository Tests (Factory Pattern)', kiss_tests.main);

    // PocketBase-specific implementation tests
    group('PocketBase-Specific Tests', pocketbase_specific_tests.main);
    group('ID Validation Tests', id_validation_tests.main);
  });
}
