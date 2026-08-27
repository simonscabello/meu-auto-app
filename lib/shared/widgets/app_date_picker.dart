import 'package:flutter/material.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/theme/app_radius.dart';

/// How far back a date field lets someone reach. Thirty years covers any car
/// an owner is plausibly still keeping records for.
const _yearsBack = 30;

/// The date picker every "when did this happen" field opens.
///
/// Four screens had byte-identical copies of this — odometer, maintenance
/// form, maintenance edit, calibrar. They share one rule worth stating once:
/// **the future is not selectable.** Every date the app posts is something
/// that already happened, the server rejects a future one, and offering a day
/// that will come back as a 422 is worse than not offering it.
///
/// Returns null when the picker is dismissed, so the caller can leave its
/// state untouched.
Future<CivilDate?> pickPastDate(
  BuildContext context, {
  required CivilDate? initial,
}) async {
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: initial == null
        ? now
        : DateTime(initial.year, initial.month, initial.day),
    firstDate: DateTime(now.year - _yearsBack),
    lastDate: now,
  );
  if (picked == null) {
    return null;
  }
  return CivilDate(picked.year, picked.month, picked.day);
}

/// The "when did this happen" field.
///
/// One shape for the four screens that ask it. Three of them drew a text row
/// with a "Mudar data" button beside it and one drew a form field, which meant
/// the same question looked like two different controls depending on where you
/// met it. It is a field: it sits in the form, it carries the label and the
/// error the way the fields around it do, and tapping anywhere on it opens
/// [pickPastDate].
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.value,
    required this.onPick,
    this.label = 'Data',
    this.emptyLabel = 'Escolher data',
    this.enabled = true,
    this.errorText,
  });

  final CivilDate? value;
  final VoidCallback onPick;
  final String label;
  final String emptyLabel;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = value;
    // A label, not a status: "Hoje" is how someone says the date they are
    // about to save, and nothing downstream branches on it.
    final isToday = current != null && current == CivilDate.todayLocal();
    final text = current == null
        ? emptyLabel
        : isToday
        ? 'Hoje'
        : formatCivilDateLong(current);

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label. $text',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onPick : null,
        borderRadius: AppRadius.borderM,
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            errorMaxLines: 3,
            suffixIcon: const Icon(Icons.event_outlined),
            enabled: enabled,
          ),
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: current == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
