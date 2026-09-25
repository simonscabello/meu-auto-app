import 'package:flutter/material.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';

/// The foot of a paginated list: the next page loading, the reason it did
/// not load with a way to try again, or the room to scroll the last row
/// clear of the thumb.
///
/// Three lists each had their own copy of this, and they had begun to
/// differ by a few pixels and a word.
class AppPagedFooter<T> extends StatelessWidget {
  const AppPagedFooter({super.key, required this.state, this.onRetry});

  final PagedState<T> state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final error = state.lastPageError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
        child: Column(
          children: [
            Text(
              error is ApiFailure
                  ? error.message
                  : 'Não foi possível carregar mais.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            AppButton(
              label: 'Tentar de novo',
              variant: AppButtonVariant.tertiary,
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return const SizedBox(height: AppSpacing.s40);
  }
}

/// A list that arrives newest first, cut into months: "Setembro de 2026".
///
/// A group closes wherever the month changes — no sorting, no second pass.
List<({String label, List<T> items})> groupByMonth<T>(
  List<T> items,
  ({int year, int month}) Function(T item) monthOf,
  String Function(T item) labelOf,
) {
  final groups = <({String label, List<T> items})>[];
  int? year;
  int? month;
  for (final item in items) {
    final at = monthOf(item);
    if (at.year != year || at.month != month) {
      year = at.year;
      month = at.month;
      groups.add((label: labelOf(item), items: <T>[]));
    }
    groups.last.items.add(item);
  }
  return groups;
}
