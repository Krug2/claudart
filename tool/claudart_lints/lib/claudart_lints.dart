import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _ClaudartLints();

class _ClaudartLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        BareStringForEnum(),
        EnumValuesLoopInSingleTest(),
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

/// Flags a `for` loop over `SomeEnum.values` nested inside a single
/// `test()` body. dartrix's `testing` paradigm (PARADIGMS.md): "Matrix-driven
/// ... Enum-owned test groups, generic bodies, test names from variant
/// identity." A loop inside one `test()` collapses every variant's pass/fail
/// into one indistinguishable result — the first failure stops the loop and
/// hides every variant after it. The loop must wrap `test()`, one call per
/// variant, never the reverse.
class EnumValuesLoopInSingleTest extends DartLintRule {
  EnumValuesLoopInSingleTest() : super(code: _code);

  static const _code = LintCode(
    name: 'enum_values_loop_in_single_test',
    problemMessage:
        'Looping over enum .values inside a single test() body collapses '
        'every variant into one pass/fail and hides which one broke.',
    correctionMessage:
        'Move the for loop outside test() — one test() call per variant, '
        'named from the variant identity.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'test') return;
      final callback = node.argumentList.arguments
          .whereType<FunctionExpression>()
          .firstOrNull;
      if (callback == null) return;

      final finder = _EnumValuesForLoopFinder();
      callback.body.accept(finder);
      for (final loop in finder.matches) {
        reporter.atNode(loop, _code);
      }
    });
  }
}

/// Collects every `for`-each loop whose iterable is a `.values` access
/// (e.g. `MyEnum.values`), found anywhere within a visited subtree.
class _EnumValuesForLoopFinder extends RecursiveAstVisitor<void> {
  final List<ForStatement> matches = [];

  @override
  void visitForStatement(ForStatement node) {
    final forLoopParts = node.forLoopParts;
    if (forLoopParts is ForEachParts && _isValuesAccess(forLoopParts.iterable)) {
      matches.add(node);
    }
    super.visitForStatement(node);
  }

  static bool _isValuesAccess(Expression iterableExpression) => switch (iterableExpression) {
        PropertyAccess(:final propertyName) => propertyName.name == 'values',
        PrefixedIdentifier(:final identifier) => identifier.name == 'values',
        _ => false,
      };
}
