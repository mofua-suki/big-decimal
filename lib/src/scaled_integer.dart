part of "big_decimal.dart";

// A canonical coefficient × 10^(-scale), with optional fixed-width display.
final class _ScaledInteger._(this.coefficient, this.scale, [this.displayScale]) {
  final BigInt coefficient;
  final int scale;
  final int? displayScale;

  static final _ten = BigInt.from(10);
  static final _five = BigInt.from(5);
  static final _literal = RegExp(r'^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$');

  factory _ScaledInteger(BigInt coefficient, int scale) {
    if (coefficient == BigInt.zero) return _ScaledInteger._(BigInt.zero, 0);
    if (coefficient.remainder(_ten) != BigInt.zero) return _ScaledInteger._(coefficient, scale);

    final digits = coefficient.toString();
    var end = digits.length;
    while (digits.codeUnitAt(end - 1) == 0x30) {
      end--;
    }
    return _ScaledInteger._(BigInt.parse(digits.substring(0, end)), scale - (digits.length - end));
  }

  factory _ScaledInteger.parse(String text) {
    final parts = _literal.firstMatch(text);
    if (parts == null) throw FormatException("$text is not a valid format");

    final fraction = parts[3] ?? "";
    final coefficient = BigInt.parse("${parts[1]}${parts[2]}$fraction");
    final exponentText = parts[4];
    final exponent = exponentText == null ? 0 : int.parse(exponentText);
    return _ScaledInteger(coefficient, fraction.length - exponent);
  }

  _ScaledInteger shift(int places) => _ScaledInteger(coefficient, scale - places);

  BigInt _coefficientAt(int targetScale) => coefficient == BigInt.zero ? coefficient : coefficient * _ten.pow(targetScale - scale);

  int compareTo(_ScaledInteger other) {
    final commonScale = scale > other.scale ? scale : other.scale;
    return _coefficientAt(commonScale).compareTo(other._coefficientAt(commonScale));
  }

  _ScaledInteger add(_ScaledInteger other) {
    final commonScale = scale > other.scale ? scale : other.scale;
    final total = _coefficientAt(commonScale) + other._coefficientAt(commonScale);
    return _ScaledInteger(total, commonScale);
  }

  _ScaledInteger subtract(_ScaledInteger other) => add(_ScaledInteger._(-other.coefficient, other.scale));

  _ScaledInteger multiply(_ScaledInteger other) => _ScaledInteger(coefficient * other.coefficient, scale + other.scale);

  _ScaledInteger divide(_ScaledInteger divisor, int targetScale, RoundingMode mode) {
    if (coefficient == BigInt.zero) return _ScaledInteger._(BigInt.zero, 0);

    final commonFactor = coefficient.gcd(divisor.coefficient);
    final numerator = coefficient ~/ commonFactor;
    final denominator = divisor.coefficient ~/ commonFactor;
    final scaleDifference = scale - divisor.scale;
    final exact = _exactQuotient(numerator, denominator, scaleDifference, targetScale);
    if (exact != null) return exact;

    final adjustment = targetScale - scaleDifference;
    final scaledNumerator = adjustment >= 0 ? numerator * _ten.pow(adjustment) : numerator;
    final scaledDenominator = adjustment < 0 ? denominator * _ten.pow(-adjustment) : denominator;
    return _ScaledInteger(_roundQuotient(scaledNumerator, scaledDenominator, mode), targetScale);
  }

  // A reduced fraction terminates in base ten only if its denominator has
  // no prime factors other than 2 and 5. Use its exact scale when it fits.
  static _ScaledInteger? _exactQuotient(BigInt numerator, BigInt denominator, int scaleDifference, int targetScale) {
    var remaining = denominator.abs();
    final twos = (remaining & -remaining).bitLength - 1;
    remaining >>= twos;

    var fives = 0;
    while (remaining.remainder(_five) == BigInt.zero) {
      remaining ~/= _five;
      fives++;
    }
    if (remaining != BigInt.one) return null;

    final digits = twos > fives ? twos : fives;
    final exactScale = scaleDifference + digits;
    if (exactScale > targetScale) return null;

    final exact = (denominator.isNegative ? -numerator : numerator) * BigInt.two.pow(digits - twos) * _five.pow(digits - fives);
    return _ScaledInteger(exact, exactScale);
  }

  _ScaledInteger rescale(int targetScale, RoundingMode mode) {
    if (targetScale >= scale) return _ScaledInteger._(coefficient, scale, targetScale);

    final unit = _ten.pow(scale - targetScale);
    final rounded = _ScaledInteger(_roundQuotient(coefficient, unit, mode), targetScale);
    return _ScaledInteger._(rounded.coefficient, rounded.scale, targetScale);
  }

  static BigInt _roundQuotient(BigInt numerator, BigInt denominator, RoundingMode mode) {
    final negative = numerator.isNegative != denominator.isNegative;
    final dividend = numerator.abs();
    final divisor = denominator.abs();
    final whole = dividend ~/ divisor;
    final remainder = dividend.remainder(divisor);

    if (remainder == BigInt.zero) return negative ? -whole : whole;

    final midpoint = (remainder << 1).compareTo(divisor);
    final increment = switch (mode) {
      RoundingMode.up => true,
      RoundingMode.down => false,
      RoundingMode.ceiling => !negative,
      RoundingMode.floor => negative,
      RoundingMode.halfUp => midpoint >= 0,
      RoundingMode.halfEven => midpoint > 0 || (midpoint == 0 && whole.isOdd),
      RoundingMode.halfDown => midpoint > 0,
    };
    final magnitude = increment ? whole + BigInt.one : whole;
    return negative ? -magnitude : magnitude;
  }

  @override
  bool operator ==(Object other) => other is _ScaledInteger && scale == other.scale && coefficient == other.coefficient;

  @override
  int get hashCode => Object.hash(coefficient, scale);

  @override
  String toString() {
    final fractionalDigits = displayScale ?? (scale > 0 ? scale : 0);
    final digits = coefficient.abs().toString() + "0" * (fractionalDigits - scale);
    final sign = coefficient.isNegative ? "-" : "";
    if (fractionalDigits == 0) return "$sign$digits";

    final padded = digits.padLeft(fractionalDigits + 1, "0");
    final point = padded.length - fractionalDigits;
    return "$sign${padded.substring(0, point)}.${padded.substring(point)}";
  }
}
