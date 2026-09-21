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
}
