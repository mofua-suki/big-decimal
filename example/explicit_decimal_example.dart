import "package:explicit_decimal/explicit_decimal.dart";

void main() {
  final amount = 123.toBigDecimal();
  final tax = amount * Percentage.fromPercent("8");
  print(tax.value); // 9.84

  final portion = amount.divide(3.toBigDecimal(), scale: PositiveInt.one, roundingMode: RoundingMode.halfEven);
  print(portion.setScale(PositiveInt.one, RoundingMode.halfEven).value); // 41.0

  final ZeroOrPositiveInt count = PositiveInt.one;
  print(count.decrement()); // 0
}
