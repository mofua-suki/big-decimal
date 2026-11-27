part of "big_decimal.dart";

// A canonical coefficient × 10^(-scale), with optional fixed-width display.
final class _ScaledInteger._(this.coefficient, this.scale, [this.displayScale]) {
  final BigInt coefficient;
  final int scale;
  final int? displayScale;

  static final _ten = BigInt.from(10);
  static final _five = BigInt.from(5);
  static final _literal = RegExp(r'^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$');

  // JavaScript numbers have 53 bits of integer precision. Native ints are signed 64-bit.
  static final _maxScale = (BigInt.one << (identical(1, 1.0) ? 53 : 63)) - BigInt.one;
  static final _minScale = identical(1, 1.0) ? -_maxScale : -_maxScale - BigInt.one;

  static int _checkedScale(BigInt value) {
    if (value < _minScale || value > _maxScale) {
      throw RangeError("Decimal scale or digit count is outside the supported integer range: $value");
    }
    return value.toInt();
  }

  static int _difference(int a, int b) => _checkedScale(BigInt.from(a) - BigInt.from(b));

  factory _ScaledInteger(BigInt coefficient, int scale) => _ScaledInteger._normalize(coefficient, BigInt.from(scale));

  factory _ScaledInteger._normalize(BigInt coefficient, BigInt scale) {
    if (coefficient == BigInt.zero) return _ScaledInteger._(BigInt.zero, 0);
    if (coefficient.remainder(_ten) != BigInt.zero) return _ScaledInteger._(coefficient, _checkedScale(scale));

    final digits = coefficient.toString();
    var end = digits.length;
    while (digits.codeUnitAt(end - 1) == 0x30) {
      end--;
    }
    return _ScaledInteger._(BigInt.parse(digits.substring(0, end)), _checkedScale(scale - BigInt.from(digits.length - end)));
  }

  factory _ScaledInteger.parse(String text) {
    final parts = _literal.firstMatch(text);
    if (parts == null) throw FormatException("$text is not a valid format");

    final fraction = parts[3] ?? "";
    final coefficient = BigInt.parse("${parts[1]}${parts[2]}$fraction");
    final exponentText = parts[4];
    final exponent = exponentText == null ? BigInt.zero : BigInt.parse(exponentText);
    final scale = BigInt.from(fraction.length) - exponent;
    if (coefficient == BigInt.zero) _checkedScale(scale);
    return _ScaledInteger._normalize(coefficient, scale);
  }

  _ScaledInteger shift(int places) => _ScaledInteger(coefficient, _difference(scale, places));

  BigInt _coefficientAt(int targetScale) => coefficient == BigInt.zero ? coefficient : coefficient * _ten.pow(_difference(targetScale, scale));

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

  _ScaledInteger multiply(_ScaledInteger other) => _ScaledInteger._normalize(coefficient * other.coefficient, BigInt.from(scale) + BigInt.from(other.scale));

  _ScaledInteger divide(_ScaledInteger divisor, int targetScale, RoundingMode mode) {
    _checkedScale(BigInt.from(targetScale));
    if (coefficient == BigInt.zero) return _ScaledInteger._(BigInt.zero, 0);

    final commonFactor = coefficient.gcd(divisor.coefficient);
    final numerator = coefficient ~/ commonFactor;
    final denominator = divisor.coefficient ~/ commonFactor;
    final scaleDifference = BigInt.from(scale) - BigInt.from(divisor.scale);
    final exact = _exactQuotient(numerator, denominator, scaleDifference, targetScale);
    if (exact != null) return exact;

    final adjustment = BigInt.from(targetScale) - scaleDifference;
    final scaledNumerator = !adjustment.isNegative ? numerator * _ten.pow(_checkedScale(adjustment)) : numerator;
    final scaledDenominator = adjustment.isNegative ? denominator * _ten.pow(_checkedScale(-adjustment)) : denominator;
    return _ScaledInteger(_roundQuotient(scaledNumerator, scaledDenominator, mode), targetScale);
  }

  // A reduced fraction terminates in base ten only if its denominator has
  // no prime factors other than 2 and 5. Use its exact scale when it fits.
  static _ScaledInteger? _exactQuotient(BigInt numerator, BigInt denominator, BigInt scaleDifference, int targetScale) {
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
    final exactScale = scaleDifference + BigInt.from(digits);
    if (exactScale > BigInt.from(targetScale)) return null;

    final exact = (denominator.isNegative ? -numerator : numerator) * BigInt.two.pow(digits - twos) * _five.pow(digits - fives);
    return _ScaledInteger._normalize(exact, exactScale);
  }

  _ScaledInteger rescale(int targetScale, RoundingMode mode) {
    _checkedScale(BigInt.from(targetScale));
    if (targetScale >= scale) return _ScaledInteger._(coefficient, scale, targetScale);

    final unit = _ten.pow(_difference(scale, targetScale));
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
    final width = fractionalDigits == 0 ? 0 : _checkedScale(BigInt.from(fractionalDigits) + BigInt.one);
    final digits = coefficient.abs().toString() + "0" * _difference(fractionalDigits, scale);
    final sign = coefficient.isNegative ? "-" : "";
    if (fractionalDigits == 0) return "$sign$digits";

    final padded = digits.padLeft(width, "0");
    final point = padded.length - fractionalDigits;
    return "$sign${padded.substring(0, point)}.${padded.substring(point)}";
  }
}
