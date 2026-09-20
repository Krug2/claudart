import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _ClaudartLints();

class _ClaudartLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        BareStringForEnum(),
      ];
}

/// Flags `switch` statements dispatching on two or more string-literal
/// `case` values. claudart's standing rule: "every user-facing literal,
/// every config key, every path, every CLI arg lives on an enhanced-enum
/// getter" — a switch on raw string literals is exactly the shape that
/// rule forbids, and `missing_enum_constant_in_switch` can't catch it
/// because the switch was never typed on an enum in the first place.
class BareStringForEnum extends DartLintRule {
  BareStringForEnum() : super(code: _code);

  static const _code = LintCode(
    name: 'bare_string_for_enum',
    problemMessage:
        'Switch dispatches on string literals instead of an enum. '
        'Model these cases as an enum and switch on it.',
    correctionMessage:
        'Introduce (or reuse) an enum whose variants are these string '
        'values, then switch on the enum.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((node) {
      final literalCases = node.members.where(_isStringLiteralCase);
      if (literalCases.length < 2) return;
      reporter.atNode(node, _code);
    });
  }

  static bool _isStringLiteralCase(SwitchMember member) {
    if (member is SwitchCase) {
      return member.expression is StringLiteral;
    }
    if (member is SwitchPatternCase) {
      final pattern = member.guardedPattern.pattern;
      return pattern is ConstantPattern && pattern.expression is StringLiteral;
    }
    return false;
  }
}
