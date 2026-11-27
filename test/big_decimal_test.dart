import "package:explicit_decimal/explicit_decimal.dart";
import "package:test/test.dart";

void main() {
  group("[UnitTest] int.toBigDecimal", () {
    for (final (value, expected) in [(0, "0"), (-123, "-123"), (9007199254740991, "9007199254740991")]) {
      test("[Positive] 整数 $value を十進数に変換する", () {
        final result = value.toBigDecimal();

        expect(result.value, expected);
      });
    }
  });

  group("[UnitTest] BigDecimal", () {
    test("スケールの上下限では値を保持し、積が範囲を超えると例外になる", () {
      final max = identical(1, 1.0) ? "9007199254740991" : "9223372036854775807";
      final tiny = BigDecimal("1e-$max");
      final large = BigDecimal("1e$max");

      expect((tiny * large) == BigDecimal("1"), isTrue);
      expect((BigDecimal("2e-$max") * BigDecimal("0.5")) == tiny, isTrue);
      expect(() => tiny * tiny, throwsRangeError);
      expect(() => large * large, throwsRangeError);
      expect(() => Percentage.fromPercent("1e-$max"), throwsRangeError);
      expect(() => BigDecimal("0.1e-$max"), throwsRangeError);
      expect(() => BigDecimal("100e$max"), throwsRangeError);
    });

    test("除算のスケール差を正確に計算する", () {
      final max = identical(1, 1.0) ? "9007199254740991" : "9223372036854775807";
      final tiny = BigDecimal("1e-$max");
      final large = BigDecimal("1e$max");
      expect(() => large.divide(tiny, scale: ZeroOrPositiveInt(0), roundingMode: RoundingMode.down), throwsRangeError);
      expect(tiny.divide(tiny, scale: ZeroOrPositiveInt(0), roundingMode: RoundingMode.down).value, "1");
    });

    test("[Positive] 符号付きの指数表記を正確にパースして通常の十進表記で表示する", () {
      expect(BigDecimal("+.01200e+4").value, "120");
      expect(BigDecimal("-12.e-4").value, "-0.0012");
      expect(BigDecimal("-0.000e+7").value, "0");
    });

    test("[Positive] 生成時と加算結果の文字列では末尾のゼロを省く", () {
      final first = BigDecimal("1.20");
      final second = BigDecimal("1.2100");

      final sum = first + second;

      expect(first.value, "1.2");
      expect(second.value, "1.21");
      expect(sum.value, "2.41");
    });

    test("[Positive] double の精度を超える値でも加減算で端数を保持する", () {
      final amount = BigDecimal("9007199254740993.03");
      final change = BigDecimal("0.07");

      final increased = amount + change;
      final restored = increased - change;

      expect(increased.value, "9007199254740993.1");
      expect(restored.value, "9007199254740993.03");
    });

    test("[Positive] BigDecimal 同士の掛け算で端数を保持する", () {
      final amount = BigDecimal("9007199254740993.03");
      final factor = BigDecimal("0.1");

      final result = amount * factor;

      expect(result.value, "900719925474099.303");
    });

    test("[Positive] 桁数の表記が異なっても数値として比較する", () {
      final amount = BigDecimal("9007199254740993.1");
      final same = BigDecimal("9007199254740993.10");
      final larger = BigDecimal("9007199254740993.11");

      expect(amount.compareTo(same), 0);
      expect(amount < larger, isTrue);
      expect(larger > amount, isTrue);
    });

    test("[Positive] 表示桁数は等値比較とハッシュに影響しない", () {
      final amount = BigDecimal("1.2");
      final padded = amount.setScale(ZeroOrPositiveInt(2), .halfEven);

      expect(padded, amount);
      expect(<BigDecimal>{amount, padded}, hasLength(1));
    });

    test("[Positive] 通常の演算の結果には表示桁数を引き継がない", () {
      final amount = BigDecimal("-1.2").setScale(ZeroOrPositiveInt(3), .halfEven);
      final half = BigDecimal("0.5").setScale(ZeroOrPositiveInt(2), .halfEven);

      expect((amount + half).value, "-0.7");
      expect((amount - half).value, "-1.7");
      expect((amount * half).value, "-0.6");
      expect(amount.divide(half, scale: ZeroOrPositiveInt(3), roundingMode: .halfEven).value, "-2.4");
      expect(amount.abs().value, "1.2");
    });
  });

  group("[UnitTest] BigDecimal.divide", () {
    /// ---------- 正常系 ---------- ///

    for (final (dividend, divisor, roundingMode, expected) in [
      ("1", "30", RoundingMode.ceiling, "1"),
      ("-1", "30", RoundingMode.floor, "-1"),
      ("1", "-30", RoundingMode.up, "-1"),
      ("1", "30", RoundingMode.down, "0"),
      ("1", "-3", RoundingMode.halfUp, "0"),
      ("-3", "2", RoundingMode.halfUp, "-2"),
      ("2", "2", RoundingMode.up, "1"),
    ]) {
      test("[Positive] $dividend ÷ $divisor を ${roundingMode.name} で整数に丸める", () {
        final result = BigDecimal(dividend).divide(BigDecimal(divisor), scale: .zero, roundingMode: roundingMode);

        expect(result.value, expected);
      });
    }

    test("[Positive] 有限小数の商が指定桁数に収まる場合はその値を返す", () {
      final dividend = BigDecimal("1.2");
      final divisor = BigDecimal("0.8");

      final result = dividend.divide(divisor, scale: ZeroOrPositiveInt(3), roundingMode: .up);

      expect(result.value, "1.5");
    });

    test("[Positive] 指定桁数が極端に大きい場合も有限小数の商をゼロ埋めしない", () {
      final result = BigDecimal("1").divide(BigDecimal("8"), scale: ZeroOrPositiveInt(1000000000), roundingMode: .halfEven);

      expect(result.value, "0.125");
    });

    test("[Positive] ゼロをゼロ以外の値で割るとゼロを返す", () {
      final result = BigDecimal.zero.divide(BigDecimal("-3"), scale: ZeroOrPositiveInt(2), roundingMode: .floor);

      expect(result.value, "0");
    });

    for (final (dividend, roundingMode, expected) in [
      ("1", RoundingMode.ceiling, "0.01"),
      ("-1", RoundingMode.floor, "-0.01"),
    ]) {
      test("[Positive] $dividend ÷ 300 の小さい端数を ${roundingMode.name} で小数第2位に丸める", () {
        final result = BigDecimal(dividend).divide(BigDecimal("300"), scale: ZeroOrPositiveInt(2), roundingMode: roundingMode);

        expect(result.value, expected);
      });
    }

    for (final (dividend, divisor, expected) in [
      ("5", "4", "1.2"),
      ("7", "4", "1.8"),
      ("5", "-4", "-1.2"),
      ("-7", "4", "-1.8"),
      ("126", "101", "1.2"), // 1.25 よりわずかに小さい循環小数
      ("124", "99", "1.3"), // 1.25 よりわずかに大きい循環小数
    ]) {
      test("[Positive] $dividend ÷ $divisor を銀行丸めで小数第1位に丸める", () {
        final result = BigDecimal(dividend).divide(BigDecimal(divisor), scale: ZeroOrPositiveInt(1), roundingMode: .halfEven);

        expect(result.value, expected);
      });
    }

    for (final (dividend, divisor, expected) in [
      ("5", "4", "1.2"),
      ("7", "4", "1.7"),
      ("5", "-4", "-1.2"),
      ("126", "101", "1.2"),
      ("124", "99", "1.3"),
    ]) {
      test("[Positive] $dividend ÷ $divisor を五捨六入で小数第1位に丸める", () {
        final result = BigDecimal(dividend).divide(BigDecimal(divisor), scale: ZeroOrPositiveInt(1), roundingMode: .halfDown);

        expect(result.value, expected);
      });
    }

    /// ---------- 異常系 ---------- ///

    test("[Negative] 0 を 0 で割ると例外が発生する", () {
      expect(() => BigDecimal.zero.divide(.zero, scale: .zero, roundingMode: .halfEven), throwsA(isA<InvalidValueException<Object?>>()));
    });

    test("[Negative] 表記上の小数桁があっても除数が 0 なら例外が発生する", () {
      final dividend = BigDecimal("1");
      final divisor = BigDecimal("0.00");

      expect(() => dividend.divide(divisor, scale: .zero, roundingMode: .down), throwsA(isA<InvalidValueException<Object?>>()));
    });
  });

  group("[UnitTest] BigDecimal.setScale", () {
    for (final (value, scale, expected) in [
      ("1.2", 2, "1.20"),
      ("1.196", 2, "1.20"),
      ("-1.196", 2, "-1.20"),
      ("0", 3, "0.000"),
    ]) {
      test("[Positive] $value を丸めて小数第$scale位まで表示する", () {
        final result = BigDecimal(value).setScale(ZeroOrPositiveInt(scale), .halfUp);

        expect(result.value, expected);
        expect(result.toString(), expected);
      });
    }

    test("[Positive] setScale を再指定すると最後に指定した桁数で表示する", () {
      final amount = BigDecimal("2.41").setScale(ZeroOrPositiveInt(4), .halfEven);

      final result = amount.setScale(ZeroOrPositiveInt(3), .halfEven);

      expect(amount.value, "2.4100");
      expect(result.value, "2.410");
    });

    for (final (roundingMode, positive, negative) in [
      (RoundingMode.up, "2", "-2"),
      (RoundingMode.down, "1", "-1"),
      (RoundingMode.ceiling, "2", "-1"),
      (RoundingMode.floor, "1", "-2"),
      (RoundingMode.halfUp, "2", "-2"),
    ]) {
      test("[Positive] ${roundingMode.name} で正負の 1.5 を整数に丸める", () {
        final positiveResult = BigDecimal("1.5").setScale(.zero, roundingMode);
        final negativeResult = BigDecimal("-1.5").setScale(.zero, roundingMode);

        expect(positiveResult.value, positive);
        expect(negativeResult.value, negative);
      });
    }

    for (final (value, expected) in [
      ("1.25", "1.2"),
      ("1.35", "1.4"),
      ("-1.25", "-1.2"),
      ("-1.35", "-1.4"),
      ("1.249", "1.2"),
      ("1.251", "1.3"),
      ("1.2", "1.2"),
    ]) {
      test("[Positive] $value を銀行丸めで小数第1位に丸める", () {
        final result = BigDecimal(value).setScale(ZeroOrPositiveInt(1), .halfEven);

        expect(result.value, expected);
      });
    }

    for (final (value, expected) in [
      ("1.249", "1.2"),
      ("1.25", "1.2"),
      ("1.251", "1.3"),
      ("-1.25", "-1.2"),
      ("-1.251", "-1.3"),
    ]) {
      test("[Positive] $value を五捨六入で小数第1位に丸める", () {
        final result = BigDecimal(value).setScale(ZeroOrPositiveInt(1), .halfDown);

        expect(result.value, expected);
      });
    }
  });
}
