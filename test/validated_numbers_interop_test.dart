import "package:explicit_decimal/explicit_decimal.dart" as decimal;
import "package:test/test.dart";
import "package:validated_numbers/validated_numbers.dart" as numbers;

void main() {
  test("the decimal API uses the validated_numbers scale types", () {
    final decimal.PositiveInt positive = numbers.PositiveInt(2);
    final numbers.ZeroOrPositiveInt zero = decimal.ZeroOrPositiveInt.zero;
    final value = decimal.BigDecimal("1.235");

    expect(value.setScale(positive, decimal.RoundingMode.halfUp).value, "1.24");
    expect(value.divide(decimal.BigDecimal("2"), scale: zero, roundingMode: decimal.RoundingMode.halfUp).value, "1");
  });

  test("integer validation exceptions retain their public identity", () {
    expect(() => decimal.PositiveInt(0), throwsA(isA<numbers.InvalidPositiveIntException>()));
    expect(() => numbers.ZeroOrPositiveInt(-1), throwsA(isA<decimal.InvalidZeroOrPositiveIntException>()));
  });
}
