import 'package:test/test.dart';

import 'id_validation_test.dart' as id_validation_tests;
import 'kiss_tests.dart' as kiss_tests;

void main() {
  group('All PocketBase Integration Tests', () {
    group('KISS Tests', kiss_tests.main);
    group('ID Validation', id_validation_tests.main);
  });
}
