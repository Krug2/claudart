// confirmation.dart — typed protocol for user confirmation gates
//
// Any skill step that must stop and confirm with the user before acting
// (e.g. /save's Step 2, /debug's pre-implementation check) uses this
// shared wire format instead of each consumer inventing its own free-text
// "did the user say yes" heuristic. One enum, one tag, one parser —
// claudart, zedup, and any future consumer classify the user's reply
// identically.
//
// Structural note: consumers that dispatch stateless per-call requests
// (no conversation history passed to the model — see claudart_runner.dart)
// MUST re-inject the pending question/handoff context into the follow-up
// call. This module only defines the wire format and parses it; it has
// no opinion on how a caller preserves context across calls.

import '../../util/enum_util.dart';
import '../xml_tags.dart';

/// The four responses a confirmation gate recognizes. Not a raw yes/no —
/// `modify` and `clarify` are distinct so the caller can route to editing
/// vs. asking a follow-up question, rather than collapsing both into
/// "no."
enum ConfirmationOption {
  /// Proceed as presented — no changes.
  confirm,

  /// The user wants to change something before proceeding.
  modify,

  /// The user's reply didn't answer confirm/modify/reject — ask again.
  clarify,

  /// Do not proceed.
  reject;

  static ConfirmationOption? fromString(String s) =>
      enumByName(ConfirmationOption.values, s);

  String get value => name;
}

/// Wire-format tag name emitted after classifying a user's reply to a
/// confirmation prompt.
const String confirmationWireTag = 'CONFIRMATION';

/// Extracts the classified [ConfirmationOption] from raw text output.
/// Returns null when the tag is absent, empty, or contains an
/// unrecognized value — callers should treat null the same as
/// [ConfirmationOption.clarify] (ask again) rather than assume intent.
ConfirmationOption? extractConfirmationOption(String rawOutput) {
  final content = tagOrNullIgnoreCase(rawOutput, confirmationWireTag);
  if (content == null || content.isEmpty) return null;
  return ConfirmationOption.fromString(content.trim());
}

/// Instructions appended to any skill's system prompt that needs a
/// confirmation gate. Lists the allowed wire values explicitly so an enum
/// rename here propagates into every consumer's prompt automatically —
/// same seam-closing rationale as `buildCategorizePrompt` in
/// categorization.dart.
String confirmationProtocolInstructions() {
  final allowed = ConfirmationOption.values.map((option) => option.name).join(', ');
  return 'When you present something for the user to confirm before '
      'proceeding, after they reply, classify their reply into exactly '
      'one of: $allowed. Emit it as '
      '<$confirmationWireTag>one of: $allowed</$confirmationWireTag> '
      'before taking the corresponding action. Do not guess — if the '
      'reply does not clearly confirm, request a change, or reject, '
      'emit `clarify` and ask a follow-up question instead of acting.';
}
