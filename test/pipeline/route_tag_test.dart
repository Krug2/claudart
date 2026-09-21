// route_tag_test.dart — RouteTag matrix.
//
// Per-variant fixture lives as an extension so adding a tag forces the
// switch arm here at compile time. Matrix iterates `RouteTag.values`
// so test surface grows automatically with the enum — no per-variant
// test function authored.

import 'package:claudart/pipeline/route_tag.dart';
import 'package:test/test.dart';

extension on RouteTag {
  /// Expected wire-format string per variant. Asserting prod against
  /// this fixture catches a rename of the wire format that doesn't
  /// propagate to either side of the contract.
  String get expectedWireTag => switch (this) {
        RouteTag.plan     => 'PLAN',
        RouteTag.question => 'QUESTION',
        RouteTag.answer   => 'ANSWER',
        RouteTag.unknown  => 'UNKNOWN',
        RouteTag.handoff  => 'HANDOFF',
        RouteTag.changes  => 'CHANGES',
      };
}

void main() {
  group('RouteTag.wireTag — one wire name per variant', () {
    for (final tag in RouteTag.values) {
      test(tag.name, () {
        expect(tag.wireTag, equals(tag.expectedWireTag));
      });
    }
  });

  group('RouteTag.wireTag — uniqueness across variants', () {
    test('no two variants share a wire name', () {
      final wireNames = RouteTag.values.map((tag) => tag.wireTag).toList();
      expect(wireNames.toSet().length, equals(wireNames.length));
    });
  });

  group('RouteTag.wireTag — non-empty per variant', () {
    for (final tag in RouteTag.values) {
      test(tag.name, () {
        expect(tag.wireTag, isNotEmpty);
      });
    }
  });

  group('RouteTag.wireTag usable as runtime map key', () {
    // Documents that `RouteTag.<v>.wireTag` is fine as a key in a
    // non-const map literal. Const map literals don't compile because
    // Dart's const-evaluation rules don't allow property access on
    // const-created enum values — that's why the production maps in
    // `flow_steps.dart` and `suggest_steps.dart` are non-const at the
    // outer level (inner StepRoute values remain const).
    final routes = <String, int>{
      for (final tag in RouteTag.values) tag.wireTag: tag.index,
    };

    test('map literal has one entry per variant', () {
      expect(routes.length, equals(RouteTag.values.length));
    });

    for (final tag in RouteTag.values) {
      test('${tag.name} — routes[wireTag] equals index', () {
        expect(routes[tag.wireTag], equals(tag.index));
      });
    }
  });
}
