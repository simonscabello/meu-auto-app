import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/catalog/application/vehicle_catalog_provider.dart';
import 'package:meu_auto/features/catalog/domain/vehicle_catalog.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// The progressive picker: brand, then model, then year.
///
/// One sheet with three steps rather than three dropdowns, because a dropdown
/// with 107 brands or 222 models is a scroll, not a choice — the list needs a
/// search field. The header says which step this is and what was already
/// chosen, so the way back is never a guess.
///
/// Picking a year fetches the detail and pops with a [VehicleCatalogSelection].
/// The form fills its own fields from that; this sheet writes nothing.
class VehicleCatalogSheet extends ConsumerStatefulWidget {
  const VehicleCatalogSheet({super.key});

  static Future<VehicleCatalogSelection?> show(BuildContext context) {
    return showAppSheet<VehicleCatalogSelection>(
      context,
      builder: (sheetContext) => const VehicleCatalogSheet(),
    );
  }

  @override
  ConsumerState<VehicleCatalogSheet> createState() =>
      _VehicleCatalogSheetState();
}

class _VehicleCatalogSheetState extends ConsumerState<VehicleCatalogSheet> {
  final _query = TextEditingController();

  VehicleBrand? _brand;
  VehicleCatalogModel? _model;

  /// Set while the detail is being fetched after a year is tapped. It is the
  /// only write-shaped wait in the sheet, so the whole list is disabled rather
  /// than one row — tapping a second year mid-flight would race the pop.
  bool _resolving = false;
  String? _resolveError;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _selectBrand(VehicleBrand brand) {
    setState(() {
      _brand = brand;
      _model = null;
      _query.clear();
    });
  }

  void _selectModel(VehicleCatalogModel model) {
    setState(() {
      _model = model;
      _query.clear();
    });
  }

  void _back() {
    setState(() {
      _resolveError = null;
      _query.clear();
      if (_model != null) {
        _model = null;
        return;
      }
      _brand = null;
    });
  }

  /// Resolves the tapped year into a selection and closes.
  ///
  /// A failure here does NOT close the sheet: the person is one tap from the
  /// answer they wanted, and dropping them back into an empty form would make
  /// them redo all three steps.
  Future<void> _selectYear(VehicleModelYear year) async {
    setState(() {
      _resolving = true;
      _resolveError = null;
    });
    try {
      final detail = await ref
          .read(vehicleCatalogRepositoryProvider)
          .detail(year.id);
      if (!mounted) return;
      Navigator.of(context).pop(VehicleCatalogSelection.fromDetail(detail));
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _resolveError = _messageFor(failure);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _resolveError = 'Algo deu errado. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetFrame(
      child: Padding(
        // The list ends above the keyboard while the search field is in use.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_brand != null) ...[
                  Transform.translate(
                    // The arrow's own padding overhangs the gutter, so the
                    // glyph lines up with the list below it.
                    offset: const Offset(-AppSpacing.s12, -AppSpacing.s8),
                    child: AppIconButton(
                      label: 'Voltar',
                      icon: Icons.arrow_back,
                      onPressed: _resolving ? null : _back,
                    ),
                  ),
                ],
                Expanded(
                  child: AppSheetHeader(
                    title: _title,
                    subtitle: _subtitle,
                    closable: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            // The year list is short and already ordered; a search field there
            // would be a control with nothing to do.
            if (_model == null) ...[
              TextField(
                controller: _query,
                enabled: !_resolving,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _brand == null ? 'Buscar marca' : 'Buscar modelo',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : AppIconButton(
                          label: 'Limpar busca',
                          icon: Icons.close,
                          onPressed: () => setState(_query.clear),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],
            if (_resolving) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: AppSpacing.s12),
            ],
            if (_resolveError != null) AuthFormBanner(message: _resolveError!),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  String get _title {
    if (_model != null) return 'Escolha o ano';
    if (_brand != null) return 'Escolha o modelo';
    return 'Escolha a marca';
  }

  /// Where the person is, and what they already picked.
  String get _subtitle {
    if (_model != null) {
      return '${_brand!.name} ${_model!.name} · passo 3 de 3';
    }
    if (_brand != null) return '${_brand!.name} · passo 2 de 3';
    return 'Passo 1 de 3';
  }

  Widget _body() {
    if (_model != null) {
      return _YearStep(
        modelId: _model!.id,
        disabled: _resolving,
        onPick: _selectYear,
      );
    }
    if (_brand != null) {
      return _ModelStep(
        brandId: _brand!.id,
        query: _query.text,
        onPick: _selectModel,
      );
    }
    return _BrandStep(query: _query.text, onPick: _selectBrand);
  }
}

/// A supplier outage reads as somebody else's problem, not the user's, and not
/// a bug in the app. Everything else keeps the server's own pt-BR message,
/// which is more specific than anything written here.
String _messageFor(ApiFailure failure) {
  if (failure.code == ApiErrorCode.upstreamUnavailable) {
    return 'A consulta à tabela FIPE está indisponível agora. '
        'Tente de novo em instantes ou preencha os dados do veículo à mão.';
  }
  return failure.message;
}

String _messageForError(Object error) {
  return error is ApiFailure
      ? _messageFor(error)
      : 'Algo deu errado. Tente novamente.';
}

class _BrandStep extends ConsumerWidget {
  const _BrandStep({required this.query, required this.onPick});

  final String query;
  final ValueChanged<VehicleBrand> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(vehicleBrandsProvider)
        .when(
          loading: () => const _ListSkeleton(count: 8),
          error: (error, _) => AppErrorState(
            message: _messageForError(error),
            onRetry: () => ref.invalidate(vehicleBrandsProvider),
          ),
          data: (brands) {
            final visible = _filterByName(brands, query, (brand) => brand.name);
            return _NameList(
              count: visible.length,
              labelAt: (index) => visible[index].name,
              onTapAt: (index) => onPick(visible[index]),
              emptyTitle: 'Nenhuma marca com esse nome',
            );
          },
        );
  }
}

class _ModelStep extends ConsumerWidget {
  const _ModelStep({
    required this.brandId,
    required this.query,
    required this.onPick,
  });

  final String brandId;
  final String query;
  final ValueChanged<VehicleCatalogModel> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(vehicleModelsProvider(brandId))
        .when(
          loading: () => const _ListSkeleton(count: 8),
          error: (error, _) => AppErrorState(
            message: _messageForError(error),
            onRetry: () => ref.invalidate(vehicleModelsProvider(brandId)),
          ),
          data: (models) {
            final visible = _filterByName(models, query, (model) => model.name);
            return _NameList(
              count: visible.length,
              labelAt: (index) => visible[index].name,
              onTapAt: (index) => onPick(visible[index]),
              emptyTitle: 'Nenhum modelo com esse nome',
            );
          },
        );
  }
}

class _YearStep extends ConsumerWidget {
  const _YearStep({
    required this.modelId,
    required this.disabled,
    required this.onPick,
  });

  final String modelId;
  final bool disabled;
  final ValueChanged<VehicleModelYear> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(vehicleModelYearsProvider(modelId))
        .when(
          loading: () => const _ListSkeleton(count: 5),
          error: (error, _) => AppErrorState(
            message: _messageForError(error),
            onRetry: () => ref.invalidate(vehicleModelYearsProvider(modelId)),
          ),
          data: (years) => _NameList(
            count: years.length,
            labelAt: (index) => years[index].displayLabel,
            onTapAt: disabled ? null : (index) => onPick(years[index]),
            emptyTitle: 'Nenhum ano para este modelo',
          ),
        );
  }
}

/// The one list all three steps use, as one grouped surface that scrolls
/// inside itself. They differ only in what a row says and what tapping it
/// does.
class _NameList extends StatelessWidget {
  const _NameList({
    required this.count,
    required this.labelAt,
    required this.onTapAt,
    required this.emptyTitle,
  });

  final int count;
  final String Function(int index) labelAt;
  final void Function(int index)? onTapAt;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (count == 0) {
      // The way out of a catalogue that does not have the car is the form
      // itself: say so, rather than leaving an empty list.
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s24),
        child: Column(
          children: [
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Tente outra busca, ou feche e digite os dados à mão.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: AppSurface(
        variant: AppSurfaceVariant.grouped,
        padding: EdgeInsets.zero,
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: count,
          separatorBuilder: (context, index) => const Padding(
            padding: EdgeInsets.only(left: AppSpacing.inset),
            child: AppRowDivider(indent: 0),
          ),
          itemBuilder: (context, index) {
            final tap = onTapAt;
            return AppGroupScope(
              horizontalPadding: AppSpacing.inset,
              child: AppListRow(
                title: labelAt(index),
                showChevron: true,
                onTap: tap == null ? null : () => tap(index),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: AppSkeleton(width: double.infinity, height: 49.0 * count),
    );
  }
}

List<T> _filterByName<T>(
  List<T> items,
  String query,
  String Function(T item) nameOf,
) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return items;
  return [
    for (final item in items)
      if (nameOf(item).toLowerCase().contains(needle)) item,
  ];
}

/// Shown on the form once a selection exists.
///
/// It is where the FIPE valuation surfaces, and where the person confirms they
/// picked the right car before saving. `fipe_price` being null is a
/// documented `200` — the source was unreachable — so the row says the value
/// is unavailable and never reads as an error: the car was still found, and
/// it can still be registered.
class VehicleCatalogSummary extends StatelessWidget {
  const VehicleCatalogSummary({
    super.key,
    required this.selection,
    required this.onChange,
    required this.onClear,
    this.enabled = true,
  });

  final VehicleCatalogSelection selection;
  final VoidCallback onChange;
  final VoidCallback onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final price = selection.fipePrice;
    final fuel = selection.fuelType;
    final meta = [
      selection.brandName,
      if (selection.modelYear != null) '${selection.modelYear}',
      if (fuel != null && fuel != FuelType.desconhecido) fuel.label,
    ].join(' · ');

    return AppGroup(
      dividerIndent: AppGroup.textIndent,
      children: [
        AppListRow(title: selection.modelName, subtitle: meta),
        if (price != null)
          AppListRow(
            title: 'Valor FIPE',
            subtitle: 'Referência: ${price.referenceLabel}',
            value: price.price.format(),
            strongValue: true,
          )
        else
          const AppListRow(
            title: 'Valor FIPE',
            subtitle: 'Indisponível agora. O cadastro funciona sem ele.',
          ),
        // Wrap rather than Row: two buttons fit side by side at the default
        // text scale and stack at a large one, instead of overflowing.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
          child: Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton(
                label: 'Trocar',
                variant: AppButtonVariant.secondary,
                compact: true,
                onPressed: enabled ? onChange : null,
              ),
              AppButton(
                label: 'Remover',
                variant: AppButtonVariant.tertiary,
                onPressed: enabled ? onClear : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The first step of the vehicle form when nothing was picked in this
/// session: one row that opens the picker, in the accent because it is an
/// action, with the reminder that typing by hand works too.
///
/// [alreadyLinked] is the edit case: the vehicle carries a catalogue link from
/// when it was registered, but this form has not fetched it. Saying so costs
/// nothing and is honest.
class VehicleCatalogPrompt extends StatelessWidget {
  const VehicleCatalogPrompt({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.alreadyLinked = false,
  });

  final VoidCallback onPressed;
  final bool enabled;
  final bool alreadyLinked;

  @override
  Widget build(BuildContext context) {
    final title = alreadyLinked
        ? 'Trocar na tabela FIPE'
        : 'Escolher na tabela FIPE';
    final help = alreadyLinked
        ? 'Veio da tabela FIPE. Trocar refaz marca, modelo, ano e '
              'combustível.'
        : 'Marca, modelo e ano. Também dá para digitar à mão.';

    return AppGroup(
      children: [
        AppListRow(
          icon: Icons.search,
          iconTone: AppIconWellTone.accent,
          title: title,
          subtitle: help,
          showChevron: true,
          onTap: enabled ? onPressed : null,
        ),
      ],
    );
  }
}
