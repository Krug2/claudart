// confirmation_test.dart — ConfirmationOption enum + wire-format round-trip.

import 'package:claudart/pipeline/agents/confirmation.dart';
import 'package:test/test.dart';

void main() {
  group('extractConfirmationOption — one row per variant', () {
    for (final option in ConfirmationOption.values) {
      test('<CONFIRMATION>${option.name}</CONFIRMATION> → ${option.name}', () {
        final raw = '<CONFIRMATION>${option.name}</CONFIRMATION>';
        expect(extractConfirmationOption(raw), equals(option));
      });
    }
  });

  test('case-insensitive — LLM may not honor UPPER_SNAKE_CASE', () {
    expect(
      extractConfirmationOption('<confirmation>Confirm</confirmation>'),
      equals(ConfirmationOption.confirm),
    );
  });

  test('missing tag returns null', () {
    expect(extractConfirmationOption('no tag here'), isNull);
  });

  test('empty tag body returns null', () {
    expect(
      extractConfirmationOption('<CONFIRMATION></CONFIRMATION>'),
      isNull,
    );
  });

  test('unrecognized value returns null', () {
    expect(
      extractConfirmationOption('<CONFIRMATION>maybe</CONFIRMATION>'),
      isNull,
    );
  });

  group('ConfirmationOption.fromString — round-trips every variant name', () {
    for (final option in ConfirmationOption.values) {
      test(option.name, () {
        expect(ConfirmationOption.fromString(option.name), equals(option));
      });
    }
  });

  group('confirmationProtocolInstructions — lists every allowed value', () {
    for (final option in ConfirmationOption.values) {
      test('mentions ${option.name}', () {
        expect(confirmationProtocolInstructions(), contains(option.name));
      });
    }
  });

  test('confirmationProtocolInstructions includes the wire tag', () {
    expect(
      confirmationProtocolInstructions(),
      contains('<$confirmationWireTag>'),
    );
  });

  test('confirmationProtocolInstructions demonstrates a wire format that '
      'actually parses — not an ambiguous schema-in-tag example', () {
    // Regression: the instructions once told the model to emit
    // <CONFIRMATION>one of: confirm, modify, clarify, reject</CONFIRMATION>
    // as if that whole string were the value. extractConfirmationOption
    // only ever matches a single enum name, so that literal example — if
    // an LLM followed it verbatim — always parsed to null. Every embedded
    // example tag in the instructions must itself be parseable.
    final instructions = confirmationProtocolInstructions();
    final tagPattern = RegExp(
      '<$confirmationWireTag>(.*?)</$confirmationWireTag>',
      caseSensitive: false,
    );
    final matches = tagPattern.allMatches(instructions).toList();
    expect(matches, isNotEmpty, reason: 'no example tag found to verify');
    for (final match in matches) {
      final parsed = extractConfirmationOption(match.group(0)!);
      expect(
        parsed,
        isNotNull,
        reason: 'embedded example "${match.group(0)}" does not parse to a '
            'ConfirmationOption — the instructions demonstrate an '
            'unparseable wire format',
      );
    }
  });
}
