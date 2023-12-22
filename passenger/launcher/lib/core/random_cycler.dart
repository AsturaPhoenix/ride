import 'dart:math';

/// Generates a random number without duplicating the last number generated. For
/// simplicity of implementation, this never starts with 0.
class RandomCycler {
  final Random random;

  /// Exclusive upper bound, > 0.
  final int n;
  int _last = 0;

  RandomCycler(this.random, this.n);

  int next() {
    int gen = random.nextInt(n - 1);
    if (gen >= _last) {
      ++gen;
    }
    _last = gen;
    return gen;
  }
}
