# Big Decimal

[English](https://github.com/mofua-suki/big-decimal/blob/main/README.md) · [pub.dev](https://pub.dev/packages/explicit_decimal)

Dart と Flutter で十進数を正確に計算できます。小数には `BigDecimal`、割合には `Percentage`、下限付きの整数には `PositiveInt` または `ZeroOrPositiveInt` を使います。

## インストール

対応する Dart SDK は 3.14.0 以上 4.0.0 未満です。

```sh
dart pub add explicit_decimal
```

Flutter プロジェクトでは `flutter pub add explicit_decimal` を実行します。

## 使用例

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

## 十進数の入力と演算

- `'19.95'`、`'-.5'`、`'1.2e3'` のような文字列を渡すか、`int` の `toBigDecimal()` を呼びます。精度を保つには元の十進表記を渡してください。`double` を経由すると、文字列に変換する前に精度が失われることがあります。
- 符号、小数点 `.`、`e` または `E` に続く指数を指定できます。仮数部には少なくとも1桁の数字が必要です。前後の空白、桁区切り、`NaN`、無限大は `FormatException` になります。
- 加算・減算・乗算・`abs()` は正確な値を返します。除算には非負の `scale` と `roundingMode` を指定します。除数が `'0.00'` など数値としてゼロなら、`invalidValue` に `Decimal` 型の `Decimal.zero` を格納した `InvalidValueException` が発生します。この判定は桁数の検証に優先します。`divide()` と `setScale()` は、`dynamic` 経由で負の桁数を渡すと `InvalidZeroOrPositiveIntException` を投げます。

| 式 | 結果 |
| --- | --- |
| `(BigDecimal('0.1') + BigDecimal('0.2')).value` | `'0.3'` |
| `(BigDecimal('1.20') - BigDecimal('0.03')).value` | `'1.17'` |
| `(BigDecimal('19.95') * Percentage.fromPercent('8')).value` | `'1.596'` |
| `BigDecimal('-2.50').abs().value` | `'2.5'` |
| `BigDecimal('1.20') == BigDecimal('1.2')` | `true` |

スケールとそこから求める桁数の範囲は、VM では符号付き64ビット整数、JavaScript では安全な整数範囲（−(2⁵³−1) から 2⁵³−1）です。たとえば、スケールがともに上限の値を掛けると `RangeError` が発生します。

## 小数桁数・表示・等値性

`scale` は小数点以下の桁数です。`divide()` は**最大**その桁数に丸めます。`setScale()` は丸めた新しい値を返し、**指定した桁数ちょうど**で表示します。

| 式 | 結果 |
| --- | --- |
| `1.toBigDecimal().divide(8.toBigDecimal(), scale: ZeroOrPositiveInt(4), roundingMode: RoundingMode.halfEven).value` | `'0.125'` |
| `BigDecimal('0.125').setScale(ZeroOrPositiveInt(4), RoundingMode.halfEven).value` | `'0.1250'` |
| `BigDecimal('0.125').setScale(ZeroOrPositiveInt(2), RoundingMode.halfEven).value` | `'0.12'` |

`value` と `toString()` は通常の十進表記を使います。`setScale()` で桁数を指定した場合を除き、小数部末尾のゼロは省きます。演算結果には元の固定表示桁数を引き継ぎません。

等値比較とハッシュは数値で決まります。`1.2` と、`setScale()` で `1.20` と表示した値は等しく、集合では1要素になります。`compareTo()` で順序を判定するときは、戻り値が負・ゼロ・正のどれかを調べます。

## 丸めモード

次の表は整数（小数桁数ゼロ）に丸めた例です。中間値とは、丸め先の二つの候補から等距離にある値です。どの桁で丸めても同じ規則を使います。

| モード | 規則 | `1.5` | `-1.5` | `2.5` | `-2.5` |
| --- | --- | ---: | ---: | ---: | ---: |
| `up` | 端数があればゼロから遠い方へ | 2 | -2 | 3 | -3 |
| `down` | ゼロの方へ | 1 | -1 | 2 | -2 |
| `ceiling` | 正の無限大の方へ | 2 | -1 | 3 | -2 |
| `floor` | 負の無限大の方へ | 1 | -2 | 2 | -3 |
| `halfUp` | 最も近い値へ。中間値はゼロから遠い方へ | 2 | -2 | 3 | -3 |
| `halfEven` | 最も近い値へ。中間値は末尾の桁が偶数の方へ | 2 | -2 | 2 | -2 |
| `halfDown` | 最も近い値へ。中間値はゼロに近い方へ | 1 | -1 | 2 | -2 |

三つの `half` モードで結果が異なるのは中間値だけです。いずれも `1.49` は `1`、`1.51` は `2` になります。`2` のように端数がなければ、どのモードでも数値は変わりません。

## 割合

- `Percentage.fromPercent('8')` は百分率、`Percentage.fromRatio('0.08')` は比率を受け取り、どちらも 8% を表します。入力には `%` を付けません。
- この例の `asPercent.value` は `'8'`、`asRatio.value` は `'0.08'` です。乗算は比率を使い正確な積を返すため、丸める時点を呼び出し側で選べます。
- 割合どうしの加減算は割合を返します。例えば、8% に 2% を加えると 10% になります。負の割合と 100% を超える割合も扱えます。
- 割合は、その比率と数値が等しい `BigDecimal` と等しく、ハッシュコードも一致します。`Percentage.fromPercent('8') == BigDecimal('0.08')` は `true` です。

## 下限付きの整数

`explicit_decimal` は [validated_numbers](https://github.com/mofua-suki/validated-numbers) の次の型を再公開しています。

| 型 | 使用できる値 | 範囲外の例外 |
| --- | --- | --- |
| `PositiveInt` | 1 以上 | `InvalidPositiveIntException` |
| `ZeroOrPositiveInt` | 0 以上 | `InvalidZeroOrPositiveIntException` |

既存の `int` はコンストラクターまたは拡張メソッド `toPositiveInt()`・`toZeroOrPositiveInt()` で検証できます。整数の表現範囲と演算は Dart の `int` に従います。`PositiveInt` は `scale` など `ZeroOrPositiveInt` を受け取る箇所にも渡せます。

`increment(maximum)` と `decrement(minimum)` は、元の値がすでに指定の境界を越えていても結果をその境界に収めます。境界を渡さない場合も結果は型の範囲内である必要があります。例えば `PositiveInt.one.decrement()` は例外を投げ、`PositiveInt.one.decrement(PositiveInt.one)` は `1` を返します。ゼロまで減る件数には `ZeroOrPositiveInt` を使います。

## 開発

このリポジトリのルートで次のコマンドを実行します。

```sh
dart pub get
dart analyze
dart test
```

使用例は `dart run example/explicit_decimal_example.dart` で実行できます。 API リファレンスは `dart doc` で生成できます。
