import 'package:flutter/material.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/shared/widgets/app_pressable.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// The mileage, set as the reading on an instrument, with the one way to
/// change it beside it.
///
/// This is the app's most frequent write and the number every distance-based
/// due date is measured from, so it is the largest figure on the screen and
/// the pencil next to it is the main — the only prominent — way in. The
/// quick actions below deliberately do not repeat it.
class MileageDisplay extends StatelessWidget {
  const MileageDisplay({
    super.key,
    required this.currentKm,
    required this.caption,
    this.stale = false,
    this.onTap,
  });

  final int currentKm;

  /// "Atualizada em 5 de setembro", or how old the reading is.
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
        Text(
          'Quilometragem atual',
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        // FittedBox rather than a smaller type ramp: seven digits at a 1.6
        // text scale on a 360dp phone is wider than the column, and shrinking
        // the one number that matters beats wrapping it onto two lines.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              text: formatKmNumber(currentKm),
              style: AppTypography.instrument(
                size: 60,
                color: scheme.onSurface,
              ),
              children: [
                TextSpan(
                  text: ' km',
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
            Flexible(
              child: Text(
                caption,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Semantics(
      button: onTap != null,
      label:
          '$caption. ${formatKm(currentKm)}.'
          '${onTap == null ? '' : ' Atualizar quilometragem'}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: reading,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.s16),
            _EditButton(onTap: onTap!),
          ],
        ],
      ),
    );
  }
}

/// The pencil: a raised disc, the accent glyph, and nothing else.
class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppPressable(
      onTap: onTap,
      child: AppSurface(
        variant: AppSurfaceVariant.raised,
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.edit_outlined, size: 22, color: scheme.primary),
        ),
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
