import 'package:kiss_repository/kiss_repository.dart';
import 'package:kiss_repository_tests/kiss_repository_tests.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:test/test.dart';

import '../integration/factories/pocketbase_query_builder.dart';

void main() {
  // `filter` only formats a string. It sends no request, so no server is
  // needed and this URL is never contacted. These tests are therefore unit
  // tests and they do not need `scripts/start_emulator.sh`.
  final client = PocketBase('http://localhost:8090');
  final builder = TestPocketBaseProductQueryBuilder(client);

  group('TestPocketBaseProductQueryBuilder QueryByName', () {
    test('quotes a plain name prefix', () {
      expect(builder.build(const QueryByName('laptop')), "name ~ 'laptop'");
    });

    test('escapes a single quote inside a legitimate value', () {
      // A real product name, not an attack. It must stay inside one literal.
      expect(builder.build(const QueryByName("O'Brien")), r"name ~ 'O\'Brien'");
    });

    test('a crafted name prefix cannot add a filter clause (#7)', () {
      // Interpolation would end the literal after `x` and append a second
      // condition. Binding escapes every quote in the value instead, so the
      // whole value stays one literal and adds no syntax of its own.
      const crafted = "x' || id != ''";

      expect(
        builder.build(const QueryByName(crafted)),
        r"name ~ 'x\' || id != \'\''",
      );
    });

    test('a double quote inside a value needs no escaping', () {
      // The emitted literal is single quoted, so a double quote is ordinary
      // text. The deleted helper escaped this character; `filter` does not.
      expect(
        builder.build(const QueryByName('say "hi"')),
        "name ~ 'say \"hi\"'",
      );
    });
  });

  group('TestPocketBaseProductQueryBuilder QueryByPriceRange', () {
    test('emits a bare number for a minimum price', () {
      expect(
        builder.build(const QueryByPriceRange(minPrice: 10.5)),
        'price >= 10.5',
      );
    });

    test('emits a bare number for a maximum price', () {
      expect(
        builder.build(const QueryByPriceRange(maxPrice: 99.99)),
        'price <= 99.99',
      );
    });

    test('joins both bounds with &&', () {
      expect(
        builder.build(const QueryByPriceRange(minPrice: 1, maxPrice: 2)),
        'price >= 1.0 && price <= 2.0',
      );
    });

    test('a bound price carries no quote character', () {
      // The bound value is a number, so `filter` must not quote it. A quoted
      // number would compare as text and change the result of the query.
      final built = builder.build(
        const QueryByPriceRange(minPrice: 1, maxPrice: 2),
      );

      expect(built.contains("'"), isFalse);
      expect(built.contains('"'), isFalse);
    });

    test('emits an empty filter when neither bound is set', () {
      expect(builder.build(const QueryByPriceRange()), '');
    });
  });

  group('TestPocketBaseProductQueryBuilder unsupported query', () {
    test('names the query type with no stray backslash', () {
      // The message used to interpolate through an escaped backslash, so it
      // read `... unsupported query type \AllQuery`.
      expect(
        () => builder.build(const AllQuery()),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            'TestPocketBaseProductQueryBuilder: unsupported query type '
                'AllQuery',
          ),
        ),
      );
    });
  });

  group('TestPocketBaseProductQueryBuilder known limit', () {
    test('a value that ends in a backslash escapes its own closing quote', () {
      // `PocketBase.filter` escapes a single quote and leaves a backslash
      // alone, so a trailing backslash lands directly before the closing
      // quote. This is upstream behaviour of `filter`, not of this builder,
      // and the deleted helper did not handle it either. The test records it
      // so a later reader does not assume the value is safe in every shape.
      expect(builder.build(const QueryByName(r'a\')), r"name ~ 'a\'");
    });
  });
}
