// usage.dart — token-usage value type for pipeline steps
//
// Promoted from private `_Usage` in suggest.dart to a public, reusable type.
// Every pipeline step returns a Usage; the executor accumulates them.
//
// Invariants:
//   ∀ u ∈ Usage: every counter ≥ 0 ∧ cost ≥ 0
//   (u1 + u2).<field> == u1.<field> + u2.<field>  for every counter

class Usage {
  final int input;
  final int output;

  /// Cache read tokens — what was billed at the cached-input rate.
  final int cacheRead;

  /// Cache *creation* tokens — what was billed at the cache-write rate
  /// (~1.25x of uncached input). First-call cost driver that shows up
  /// when the prompt is being written into the cache for later reuse.
  /// Surfacing it separately lets the trace explain why first-call
  /// cost is higher than subsequent calls hitting the same cache.
  final int cacheCreation;

  final double cost;

  /// Output tokens spent on extended thinking, a subset of [output] (the
  /// API bills thinking tokens as output tokens — this is a breakdown, not
  /// an additional cost). Zero when the model didn't reason before
  /// answering, or when the CLI response didn't report the breakdown.
  final int thinkingTokens;

  const Usage({
    this.input        = 0,
    this.output       = 0,
    this.cacheRead    = 0,
    this.cacheCreation = 0,
    this.cost         = 0,
    this.thinkingTokens = 0,
  });

  Usage operator +(Usage o) => Usage(
    input:          input          + o.input,
    output:         output         + o.output,
    cacheRead:      cacheRead      + o.cacheRead,
    cacheCreation:  cacheCreation  + o.cacheCreation,
    cost:           cost           + o.cost,
    thinkingTokens: thinkingTokens + o.thinkingTokens,
  );

  /// Human-readable summary for terminal display.
  /// Example: 'in 3.2k · cached 1.1k · out 412 · $0.0008'
  String format() {
    final buf = StringBuffer('in ${_fmtN(input)}');
    if (cacheRead > 0) buf.write(' · cached ${_fmtN(cacheRead)}');
    if (cacheCreation > 0) buf.write(' · cache-wr ${_fmtN(cacheCreation)}');
    buf.write(' · out ${_fmtN(output)}');
    if (thinkingTokens > 0) buf.write(' (${_fmtN(thinkingTokens)} thinking)');
    if (cost > 0) buf.write(' · \$${cost.toStringAsFixed(4)}');
    return buf.toString();
  }

  @override
  String toString() =>
      'Usage(in:$input, out:$output, cached:$cacheRead, '
      'cacheWrite:$cacheCreation, thinking:$thinkingTokens, \$$cost)';
}

String _fmtN(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
