import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_typography.dart';

/// Formats digits into `R$ 4.200,00` while they are typed.
///
/// The convention is the card machine's: digits fill from the cents up, so
/// `42000` reads `R$ 420,00` and there is no decimal separator to place
/// wrong. What changed is that the person now *sees* that, instead of being
/// told about it in a helper line under an unformatted number.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.maxDigits = 9});

  /// Nine digits is `R$ 9.999.999,99` — the ceiling the write already had.
  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = digitsOnly(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue();
    }
    final kept = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;
    final cents = int.parse(kept);
    // Backspacing through `R$ 0,00` has to empty the field. Without this the
    // zeros re-mask themselves and the field cannot be cleared.
    if (cents == 0 && newValue.text.length < oldValue.text.length) {
      return const TextEditingValue();
    }
    final text = Money.fromCents(cents).format();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Formats digits into `98.450` while they are typed.
///
/// A six or seven digit odometer reading is checked by eye, standing up, and
/// a wrong one costs a rollback dialog. Grouping the thousands is what makes
/// it checkable.
class KmInputFormatter extends TextInputFormatter {
  const KmInputFormatter({this.maxDigits = 7});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = digitsOnly(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue();
    }
    final kept = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;
    // Zero is a real mileage — a car delivered today — so it is never
    // cleared the way an empty amount is.
    final text = formatKmNumber(int.parse(kept));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// A money field. Reads back with [centsFromMoneyField].
class AppMoneyField extends StatelessWidget {
  const AppMoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.errorText,
    this.helperText,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? errorText;
  final String? helperText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(signed: false),
      textInputAction: textInputAction,
      inputFormatters: const [MoneyInputFormatter()],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(fontFeatures: AppTypography.tabular),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'R\$ 0,00',
        helperText: helperText,
        errorText: errorText,
        errorMaxLines: 3,
      ),
    );
  }
}

/// A mileage field. Reads back with [kmFromField].
class AppKmField extends StatelessWidget {
  const AppKmField({
    super.key,
    required this.controller,
    this.label = 'Quilometragem',
    this.enabled = true,
    this.autofocus = false,
    this.errorText,
    this.helperText,
    this.textStyle,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool autofocus;
  final String? errorText;
  final String? helperText;
  final TextStyle? textStyle;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final base = textStyle ?? Theme.of(context).textTheme.bodyLarge;
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(signed: false),
      textInputAction: textInputAction,
      inputFormatters: const [KmInputFormatter()],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: base?.copyWith(fontFeatures: AppTypography.tabular),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'km',
        helperText: helperText,
        errorText: errorText,
        errorMaxLines: 3,
      ),
    );
  }
}

/// Puts [km] in a controller already wearing the mask, with the whole value
/// selected so the first keystroke replaces it.
///
/// Prefilling the current reading is what makes the odometer sheet a two-tap
/// job; selecting it is what stops the new number being appended to the old.
TextEditingController kmController(int km) {
  final text = formatKmNumber(km);
  return TextEditingController(text: text)
    ..selection = TextSelection(baseOffset: 0, extentOffset: text.length);
}

/// Resets [controller] to [km], masked and fully selected.
void setKmText(TextEditingController controller, int km) {
  final text = formatKmNumber(km);
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: 0, extentOffset: text.length),
  );
}
