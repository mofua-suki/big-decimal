## 0.1.3

- Reject negative scales passed dynamically to `divide` and `setScale` with `InvalidZeroOrPositiveIntException`. Division by zero still takes precedence and reports `Decimal.zero` as the invalid value.
- Skip scale alignment when zero or opposite signs determine the comparison result.

## 0.1.2

- Check decimal scales and digit counts before converting to platform integers. Out-of-range operations throw `RangeError`.

## 0.1.1

- Use validated integer types from `validated_numbers` and continue exporting them from the existing library entry point.
- Add a Japanese README and link both language editions to pub.dev.

## 0.1.0

- Add exact decimal arithmetic with explicit scale and rounding for division.
- Add percentages with percent and ratio constructors, percentage addition and subtraction, and multiplication by decimals.
- Add positive and non-negative integer types, along with integer conversion extensions.
