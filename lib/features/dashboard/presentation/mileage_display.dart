import 'package:flutter/material.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';

/// The mileage, set as a reading, with the way to update it on the same line.
///
/// This is the app's most frequent write and the number every distance-based
/// due date is measured from, so it is the largest figure on the screen. The
/// way to change it is a text action beside it — "Atualizar" — rather than a
/// big button: it is always there and always obvious, and it never outweighs
/// the reading it changes. The whole block is also a way in, for the thumb
/// that lands on the number.
class MileageDisplay extends StatelessWidget {
  const MileageDisplay({
    super.key,
    required this.currentKm,
    required this.caption,
    this.stale = false,
    this.onTap,
  });

  final int currentKm;

  /// "Atualizada hoje", or how old the reading is.
  final String caption;

  /// Whether the caption is asking for a new reading.
  final bool stale;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final reading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // FittedBox rather than a smaller size: seven digits at a 1.6 text
        // scale on a 360dp phone is wider than the column, and shrinking the
        // one number that matters beats wrapping it onto two lines.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              text: formatKmNumber(currentKm),
              style: AppTypography.figure(size: 44, color: scheme.onSurface),
              children: [
                TextSpan(
                  text: '${nbsp}km',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            if (stale) ...[
              Icon(
                Icons.update_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.s4),
            ],
            Flexible(child: Text(caption, style: theme.textTheme.bodySmall)),
          ],
        ),
      ],
    );

    final tappableReading = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: reading,
    );
    final update = onTap == null
        ? null
        : TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Atualizar'),
          );
    // Past 1.3 the action beside the reading squeezed the number down to
    // fit; under it, the reading keeps the whole line.
    final stacked = AppTypography.isLargeText(context);

    return Semantics(
      container: true,
      button: onTap != null,
      label:
          '${formatKm(currentKm)}. $caption.'
          '${onTap == null ? '' : ' Atualizar quilometragem'}',
      excludeSemantics: true,
      onTap: onTap,
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tappableReading,
                if (update != null)
                  Transform.translate(
                    // The icon, not the ink, lines up with the gutter.
                    offset: const Offset(-AppSpacing.s12, 0),
                    child: update,
                  ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: tappableReading),
                if (update != null) ...[
                  const SizedBox(width: AppSpacing.s12),
                  Transform.translate(
                    // The text button's padding overhangs the gutter so its
                    // label, not its ink, lines up with the edge of the
                    // cards below.
                    offset: const Offset(AppSpacing.s12, 0),
                    child: update,
                  ),
                ],
              ],
            ),
    );
  }
}

/// How old the mileage is, when that matters.
///
/// Every distance-based due date is measured from this number, and the server
/// has no way to know the car kept moving. A reading months old makes "faltam
/// 3.000 km" a guess, so past about six weeks the caption says how old it is
/// and asks for a new one — the whole block is already the way to update it.
String odometerCaption(CivilDate? recordedOn, CivilDate? today) {
  if (recordedOn == null) return 'Sem data da leitura';
  if (today == null) return 'Atualizada em ${formatCivilDayMonth(recordedOn)}';
  final days = recordedOn.daysUntil(today);
  if (days <= 0) return 'Atualizada hoje';
  if (days == 1) return 'Atualizada ontem';
  if (days <= _staleAfterDays) {
    return 'Atualizada em ${formatCivilDayMonth(recordedOn)}';
  }
  final months = (days / 30).round();
  final age = months <= 1 ? 'há mais de um mês' : 'há $months meses';
  return 'Atualizada $age — toque para conferir';
}

/// Whether [odometerCaption] is asking for a new reading.
bool odometerIsStale(CivilDate? recordedOn, CivilDate? today) {
  if (recordedOn == null || today == null) return false;
  return recordedOn.daysUntil(today) > _staleAfterDays;
}

const _staleAfterDays = 45;
