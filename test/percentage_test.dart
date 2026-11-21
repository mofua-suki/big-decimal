import "package:explicit_decimal/explicit_decimal.dart";
import "package:test/test.dart";

void main() {
  group("[UnitTest] Percentage", () {
    test("[Positive] 百分率と比率を区別して生成できる", () {
      final fromPercent = Percentage.fromPercent("8");
      final fromRatio = Percentage.fromRatio("0.08");

      expect(fromPercent.asRatio.value, "0.08");
      expect(fromRatio.asPercent.value, "8");
    });

    test("[Positive] 比率と等しい BigDecimal は表示桁数に関わらず等値になる", () {
      final amount = BigDecimal("0.08").setScale(ZeroOrPositiveInt(4), .halfEven);
      final rate = Percentage.fromPercent("8");

      expect(amount == rate, isTrue);
      expect(rate == amount, isTrue);
      expect(<Object?>{amount, rate}, hasLength(1));
    });

    test("[Positive] 8% を掛けて税額を計算する", () {
      final amount = BigDecimal("1000");
      final rate = Percentage.fromPercent("8");

      final tax = amount * rate;

      expect(tax.value, "80");
    });

    for (final (percent, expected) in [
      ("0", "0"),
      ("-2.5", "-5"),
      ("8.125", "16.25"),
      ("108", "216"),
    ]) {
      test("[Positive] 200 に $percent% を掛けても丸めずに計算する", () {
        final amount = BigDecimal("200");
        final rate = Percentage.fromPercent(percent);

        final result = amount * rate;

        expect(result.value, expected);
      });
    }

    test("[Positive] 掛け算では端数を保持し、呼び出し側で丸められる", () {
      final amount = BigDecimal("123");
      final rate = Percentage.fromPercent("10");

      final exact = amount * rate;
      final rounded = exact.setScale(.zero, .ceiling);

      expect(exact.value, "12.3");
      expect(rounded.value, "13");
    });

    test("[Positive] Percentage 同士の加減算は Percentage を返す", () {
      final reduced = Percentage.fromPercent("8");
      final difference = Percentage.fromPercent("2");

      final Percentage standard = reduced + difference;
      final Percentage lower = difference - reduced;

      expect(standard.asPercent.value, "10");
      expect(lower.asPercent.value, "-6");
    });
  });
}
