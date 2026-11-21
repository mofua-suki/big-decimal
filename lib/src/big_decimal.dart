import "package:decimal/decimal.dart";
import "package:meta/meta.dart";
import "package:validated_numbers/validated_numbers.dart" show InvalidValueException, ZeroOrPositiveInt;

part "scaled_integer.dart";

/// An immutable, arbitrary-precision decimal number.
///
/// Create a value from decimal text, such as `BigDecimal("19.95")`, or use
/// [IntBigDecimalExtension.toBigDecimal] for an integer. Pass the original
/// decimal text when exactness matters. A `double` may have lost precision
/// before it is converted to text.
///
/// Addition, subtraction, and multiplication are exact and return new values.
/// [divide] requires a non-negative number of fractional digits and a
/// [RoundingMode]. Use scale zero to round to an integer.
///
/// [value] and [toString] normally omit trailing fractional zeros. Use
/// [setScale] to round a value and display exactly the requested number of
/// fractional digits. Subsequent arithmetic uses the numeric value and
/// returns the usual display format. For example, a number displayed as
/// `1.20` equals `BigDecimal("1.2")` and has the same hash code.
/// A [Percentage] compares equal to the decimal value of its ratio.
///
/// ```dart
/// final amount = BigDecimal("19.95");
/// final tax = amount * Percentage.fromPercent("8");
/// print(tax.value); // 1.596
/// print(tax.setScale(ZeroOrPositiveInt(2), RoundingMode.halfEven)); // 1.60
/// ```
@immutable
extension type const BigDecimal._(_ScaledInteger _number) implements DecimalFactor {
  /// Parses a signed decimal literal, with an optional base-10 exponent.
  ///
  /// For example, `"19.95"`, `"-.5"`, and `"1.2e3"` are valid.
  /// Use a period as the decimal point. At least one mantissa digit is
  /// required. Surrounding whitespace, grouping separators, `NaN`, and
  /// infinity cause a [FormatException].
  factory BigDecimal(String value) => BigDecimal._(_ScaledInteger.parse(value));

  /// The number zero.
  static final zero = BigDecimal._(_ScaledInteger(BigInt.zero, 0));

  /// The number one hundred.
  static final hundred = BigDecimal._(_ScaledInteger(BigInt.one, -2));

  /// Returns a negative number, zero, or a positive number as this value
  /// is less than, equal to, or greater than [other].
  ///
  /// Displayed fractional digits do not affect the comparison.
  int compareTo(BigDecimal other) => _number.compareTo(other._number);

  /// Whether this number is less than [other].
  bool operator <(BigDecimal other) => compareTo(other) < 0;

  /// Whether this number is less than or equal to [other].
  bool operator <=(BigDecimal other) => compareTo(other) <= 0;

  /// Whether this number is greater than [other].
  bool operator >(BigDecimal other) => compareTo(other) > 0;

  /// Whether this number is greater than or equal to [other].
  bool operator >=(BigDecimal other) => compareTo(other) >= 0;

  /// Returns the exact sum.
  BigDecimal operator +(BigDecimal other) => BigDecimal._(_number.add(other._number));

  /// Returns the exact sum.
  BigDecimal add(BigDecimal other) => this + other;

  /// Returns the exact difference.
  BigDecimal operator -(BigDecimal other) => BigDecimal._(_number.subtract(other._number));

  /// Returns the exact difference.
  BigDecimal subtract(BigDecimal other) => this - other;

  /// Returns the exact product. A [Percentage] contributes its ratio.
  BigDecimal operator *(DecimalFactor other) => BigDecimal._(_number.multiply(other._factor));

  /// Returns the exact product. A [Percentage] contributes its ratio.
  BigDecimal multiply(DecimalFactor other) => this * other;

  /// Divides by [divisor] and rounds to at most [scale] fractional digits.
  ///
  /// [roundingMode] applies when the exact quotient cannot fit at [scale],
  /// including when the quotient has a repeating decimal expansion.
  /// For example, dividing `1` by `8` at scale two with [RoundingMode.halfEven]
  /// yields `0.12`. The same division at scale four yields `0.125`.
  ///
  /// The result uses the usual display format without trailing fractional
  /// zeros. To display exactly [scale] fractional digits, apply [setScale] to
  /// the result using the same scale. Throws [InvalidValueException] if
  /// [divisor] is numerically zero, including a divisor parsed from `"0.00"`.
  BigDecimal divide(
    BigDecimal divisor, {
    required ZeroOrPositiveInt scale,
    required RoundingMode roundingMode,
  }) {
    if (divisor._number.coefficient == BigInt.zero) {
      // Preserve the public exception's value type from the previous implementation.
      throw InvalidValueException(invalidValue: Decimal.zero, message: "divisor must not be zero");
    }
    return BigDecimal._(_number.divide(divisor._number, scale, roundingMode));
  }

  /// Returns the absolute value using the usual display format.
  BigDecimal abs() => BigDecimal._(_ScaledInteger(_number.coefficient.abs(), _number.scale));

  /// Rounds to [scale] fractional digits and displays exactly that many.
  ///
  /// When reducing precision, [roundingMode] determines the numeric result.
  /// When the value already fits at [scale], it is numerically unchanged.
  /// For example, requesting two digits for `1.2` displays `1.20` in both
  /// [value] and [toString]. Padding affects display only. Arithmetic
  /// results use the usual display format again.
  BigDecimal setScale(ZeroOrPositiveInt scale, RoundingMode roundingMode) => BigDecimal._(_number.rescale(scale, roundingMode));

  /// The value in plain decimal notation.
  ///
  /// Trailing fractional zeros are omitted unless [setScale] requested fixed
  /// digits. For example, parsing `"1.20e3"` gives `"1200"`.
  String get value => _number.toString();
}

/// Exact conversion from a Dart integer to a decimal.
extension IntBigDecimalExtension on int {
  /// Returns this integer as a [BigDecimal].
  BigDecimal toBigDecimal() => BigDecimal._(_ScaledInteger(BigInt.from(this), 0));
}

/// A value that can multiply a [BigDecimal].
///
/// A [BigDecimal] supplies its own value. A [Percentage] supplies its ratio,
/// so multiplying by eight percent is equivalent to multiplying by `0.08`.
extension type const DecimalFactor._(_ScaledInteger _factor) {}

/// An immutable percentage whose numeric value is its ratio.
///
/// Use `Percentage.fromPercent` when the input is written in percent units
/// and `Percentage.fromRatio` when the input is already a ratio. For example,
/// `Percentage.fromPercent("8")` equals `Percentage.fromRatio("0.08")`
/// and `BigDecimal("0.08")`. Use [asPercent] for percent units or [asRatio]
/// for the value used in multiplication.
///
/// Negative rates and rates above 100% are accepted. Adding or subtracting
/// two percentages returns a percentage. Multiplying a [BigDecimal] by a
/// percentage returns an exact decimal, leaving any rounding to the caller.
@immutable
extension type const Percentage._(_ScaledInteger _ratio) implements DecimalFactor {
  /// Parses percent units, so `"8"` means eight percent.
  ///
  /// Pass decimal text without a percent sign. Invalid text throws a
  /// [FormatException].
  factory Percentage.fromPercent(String value) => Percentage._(_ScaledInteger.parse(value).shift(-2));

  /// Parses a ratio, so `"0.08"` means eight percent and `"1"` means 100%.
  ///
  /// Invalid decimal text throws a [FormatException].
  factory Percentage.fromRatio(String value) => Percentage._(_ScaledInteger.parse(value));

  /// The ratio, such as `0.08` for eight percent.
  BigDecimal get asRatio => BigDecimal._(_ratio);

  /// The numeric value in percent units, such as `8` for eight percent.
  BigDecimal get asPercent => BigDecimal._(_ratio.shift(2));

  /// Adds the two percentages.
  Percentage operator +(Percentage other) => Percentage._(_ratio.add(other._ratio));

  /// Subtracts [other] from this percentage.
  Percentage operator -(Percentage other) => Percentage._(_ratio.subtract(other._ratio));
}

/// How to round when a result has more fractional digits than requested.
///
/// A tie is a value exactly halfway between the two nearest results at the
/// requested scale. The three nearest-value modes differ only at ties.
/// [BigDecimal.divide] and [BigDecimal.setScale] leave values that already
/// fit the requested scale numerically unchanged. The examples below use
/// scale zero to round to an integer.
enum RoundingMode {
  /// Away from zero whenever the discarded part is nonzero.
  ///
  /// `1.1 → 2` and `-1.1 → -2`.
  up,

  /// Toward zero, discarding the extra fractional digits.
  ///
  /// `1.9 → 1` and `-1.9 → -1`.
  down,

  /// Toward positive infinity.
  ///
  /// `1.1 → 2` and `-1.1 → -1`.
  ceiling,

  /// Toward negative infinity.
  ///
  /// `1.1 → 1` and `-1.1 → -2`.
  floor,

  /// To the nearest value, with ties rounded away from zero.
  ///
  /// `1.5 → 2` and `-1.5 → -2`.
  halfUp,

  /// To the nearest value, with ties rounded to an even last retained digit.
  ///
  /// `1.5 → 2`, `2.5 → 2`, and `-2.5 → -2`.
  halfEven,

  /// To the nearest value, with ties rounded toward zero.
  ///
  /// `1.5 → 1` and `-1.5 → -1`.
  halfDown,
}
