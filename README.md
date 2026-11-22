# Big Decimal

Exact base-10 arithmetic for Dart and Flutter. Use `BigDecimal` for decimal values, `Percentage` for rates, and `PositiveInt` or `ZeroOrPositiveInt` for integer inputs with a minimum value.

## Install

The package name is `explicit_decimal`. It requires Dart 3.14 or newer,
below Dart 4.

```sh
dart pub add explicit_decimal
```

For Flutter projects, run `flutter pub add explicit_decimal`.

## Quick start

```dart
import 'package:explicit_decimal/explicit_decimal.dart';

void main() {
  final amount = BigDecimal('19.95');
  final rate = Percentage.fromPercent('8');
  final scale = ZeroOrPositiveInt(2);

  final tax = amount * rate;
  print(tax.value); // 1.596
  print(tax.setScale(scale, RoundingMode.halfEven).value); // 1.60

  final share = amount.divide(
    3.toBigDecimal(),
    scale: scale,
    roundingMode: RoundingMode.halfEven,
  );
  print(share.value); // 6.65
}
```

## Decimal input and arithmetic

- Pass a string such as `'19.95'`, `'-.5'`, or `'1.2e3'`, or call `toBigDecimal()` on an `int`. Pass the original decimal text to preserve precision. A `double` may have already lost precision before it is converted to text.
- The parser accepts an optional sign, a decimal point written as `.`, and an optional `e` or `E` exponent. At least one digit is required in the mantissa. Surrounding whitespace, grouping separators, `NaN`, and infinity are rejected with `FormatException`.
- Addition, subtraction, multiplication, and `abs()` keep the exact numeric result. Division requires a non-negative `scale` and a `roundingMode`. A zero divisor, including `'0.00'`, throws `InvalidValueException`.

| Expression | Result |
| --- | --- |
| `(BigDecimal('0.1') + BigDecimal('0.2')).value` | `'0.3'` |
| `(BigDecimal('1.20') - BigDecimal('0.03')).value` | `'1.17'` |
| `(BigDecimal('19.95') * Percentage.fromPercent('8')).value` | `'1.596'` |
| `BigDecimal('-2.50').abs().value` | `'2.5'` |
| `BigDecimal('1.20') == BigDecimal('1.2')` | `true` |

## Scale, display, and equality

`scale` is the number of fractional digits. `divide()` rounds the number to **at most** that many digits. `setScale()` rounds the number and displays **exactly** that many digits. It returns a new value. For example:

| Expression | Result |
| --- | --- |
| `1.toBigDecimal().divide(8.toBigDecimal(), scale: ZeroOrPositiveInt(4), roundingMode: RoundingMode.halfEven).value` | `'0.125'` |
| `BigDecimal('0.125').setScale(ZeroOrPositiveInt(4), RoundingMode.halfEven).value` | `'0.1250'` |
| `BigDecimal('0.125').setScale(ZeroOrPositiveInt(2), RoundingMode.halfEven).value` | `'0.12'` |

Both `value` and `toString()` use plain decimal notation. Outside of `setScale()`, values omit trailing fractional zeros. Arithmetic starts from the numeric values and does not carry fixed-width display into its results.

Equality and hashing use the numeric value. This means `1.2` and a `setScale()` result displayed as `1.20` compare equal and occupy one entry in a set. `compareTo()` returns a negative value, zero, or a positive value. Use its sign when checking ordering.

## Rounding modes

These examples round to an integer (scale zero). A tie is exactly halfway between the two nearest results. The same rules apply at every scale.

| Mode | Rule | `1.5` | `-1.5` | `2.5` | `-2.5` |
| --- | --- | ---: | ---: | ---: | ---: |
| `up` | Away from zero for inexact results | 2 | -2 | 3 | -3 |
| `down` | Toward zero | 1 | -1 | 2 | -2 |
| `ceiling` | Toward positive infinity | 2 | -1 | 3 | -2 |
| `floor` | Toward negative infinity | 1 | -2 | 2 | -3 |
| `halfUp` | Nearest, ties away from zero | 2 | -2 | 3 | -3 |
| `halfEven` | Nearest, ties to an even last retained digit | 2 | -2 | 2 | -2 |
| `halfDown` | Nearest, ties toward zero | 1 | -1 | 2 | -2 |

The three `half` modes differ only at exact ties. For example, all three round `1.49` to `1` and `1.51` to `2`. An exact result such as `2` stays numerically unchanged in every mode.

## Percentages

- `Percentage.fromPercent('8')` reads percent units. `Percentage.fromRatio('0.08')` reads a ratio. Both represent 8%. Pass the numeric text without a `%` suffix.
- `asPercent.value` gives `'8'`. `asRatio.value` gives `'0.08'`. Multiplication by a percentage uses its ratio and keeps the exact result so you can decide when to round.
- Addition and subtraction take two percentages and return a percentage. For example, adding 8% and 2% gives 10%. Negative rates and rates above 100% are accepted.
- A percentage and a `BigDecimal` with the same numeric ratio compare equal and have the same hash code, so `Percentage.fromPercent('8') == BigDecimal('0.08')` is `true`.

## Validated integers

`explicit_decimal` re-exports these types from [`validated_numbers`](https://github.com/mofua-suki/validated-numbers).

| Type | Accepted values | Exception outside the range |
| --- | --- | --- |
| `PositiveInt` | `1` and above | `InvalidPositiveIntException` |
| `ZeroOrPositiveInt` | `0` and above | `InvalidZeroOrPositiveIntException` |

Use a constructor or the `toPositiveInt()` and `toZeroOrPositiveInt()` extensions to validate an existing `int`. These types use Dart's `int` range and arithmetic. A `PositiveInt` can be passed where `ZeroOrPositiveInt` is expected, including as a scale.

`increment(maximum)` and `decrement(minimum)` clamp the result to the supplied bound, even if the starting value is already outside that bound. Without a bound, the result must stay in range. For example, `PositiveInt.one.decrement()` throws, while `PositiveInt.one.decrement(PositiveInt.one)` returns `1`. If a count is allowed to reach zero, use `ZeroOrPositiveInt`.

## Development

- `dart analyze` checks the package.
- `dart test` runs the tests.
- `dart doc` generates the API documentation.
