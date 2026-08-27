import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/catalog/application/vehicle_catalog_provider.dart';
import 'package:meu_auto/features/catalog/domain/vehicle_catalog.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// The progressive picker: brand, then model, then year.
///
/// One sheet with three steps rather than three dropdowns, because a dropdown
/// with 107 brands or 222 models is a scroll, not a choice — the list needs a
/// search field, and that is what `ItemPickerSheet` already established for the
/// maintenance catalogue.
///
/// Picking a year fetches the detail and pops with a [VehicleCatalogSelection].
/// The form fills its own fields from that; this sheet writes nothing.
class VehicleCatalogSheet extends ConsumerStatefulWidget {
  const VehicleCatalogSheet({super.key});

  static Future<VehicleCatalogSelection?> show(BuildContext context) {
    return showModalBottomSheet<VehicleCatalogSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
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
  /// them redo all three steps. It shows the message inline and leaves the
  /// list tappable again.
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
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.85;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          0,
          AppSpacing.s16,
          AppSpacing.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_brand != null)
                  IconButton(
                    onPressed: _resolving ? null : _back,
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Voltar',
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_title, style: theme.textTheme.titleLarge),
                      if (_breadcrumb != null)
                        Text(
                          _breadcrumb!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
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
                decoration: const InputDecoration(
                  labelText: 'Buscar',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
            if (_resolveError != null) ...[
              _InlineError(message: _resolveError!),
              const SizedBox(height: AppSpacing.s12),
            ],
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  String get _title {
    if (_model != null) return 'Ano e combustível';
    if (_brand != null) return 'Modelo';
    return 'Marca';
  }

  String? get _breadcrumb {
    if (_model != null) return '${_brand!.name} · ${_model!.name}';
    if (_brand != null) return _brand!.name;
    return null;
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.s8),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
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
          loading: () => const AppSkeletonList(count: 8, itemHeight: 56),
          error: (error, _) => AppErrorState(
            message: error is ApiFailure
                ? _messageFor(error)
                : 'Algo deu errado. Tente novamente.',
            onRetry: () => ref.invalidate(vehicleBrandsProvider),
          ),
          data: (brands) {
            final visible = _filterByName(brands, query, (brand) => brand.name);
            return _NameList(
              count: visible.length,
              labelAt: (index) => visible[index].name,
              onTapAt: (index) => onPick(visible[index]),
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
          loading: () => const AppSkeletonList(count: 8, itemHeight: 56),
          error: (error, _) => AppErrorState(
            message: error is ApiFailure
                ? _messageFor(error)
                : 'Algo deu errado. Tente novamente.',
            onRetry: () => ref.invalidate(vehicleModelsProvider(brandId)),
          ),
          data: (models) {
            final visible = _filterByName(models, query, (model) => model.name);
            return _NameList(
              count: visible.length,
              labelAt: (index) => visible[index].name,
              onTapAt: (index) => onPick(visible[index]),
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
          loading: () => const AppSkeletonList(count: 6, itemHeight: 56),
          error: (error, _) => AppErrorState(
            message: error is ApiFailure
                ? _messageFor(error)
                : 'Algo deu errado. Tente novamente.',
            onRetry: () => ref.invalidate(vehicleModelYearsProvider(modelId)),
          ),
          data: (years) => _NameList(
            count: years.length,
            labelAt: (index) => years[index].displayLabel,
            onTapAt: disabled ? null : (index) => onPick(years[index]),
          ),
        );
  }
}

/// The one list widget all three steps use. They differ only in what a row
/// says and what tapping it does.
class _NameList extends StatelessWidget {
  const _NameList({
    required this.count,
    required this.labelAt,
    required this.onTapAt,
  });

  final int count;
  final String Function(int index) labelAt;
  final void Function(int index)? onTapAt;

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s24),
          child: Text(
            'Nada com esse nome. Tente outra busca.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: count,
      itemBuilder: (context, index) {
        final tap = onTapAt;
        return ListTile(
          title: Text(labelAt(index)),
          trailing: const Icon(Icons.chevron_right),
          onTap: tap == null ? null : () => tap(index),
        );
      },
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
/// picked the right car before saving. `fipe_price` being null is normal — the
/// card simply says the value is unavailable rather than reading as an error.
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
    final theme = Theme.of(context);
    final price = selection.fipePrice;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.s8),
                // Expanded, not bare: at a 1.3 text scale on a 360px screen
                // this label is wider than what is left beside the icon, and a
                // Row does not wrap on its own.
                Expanded(
                  child: Text(
                    'Selecionado da tabela FIPE',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(selection.brandName, style: theme.textTheme.bodyMedium),
            Text(selection.modelName, style: theme.textTheme.titleMedium),
            if (selection.modelYear != null)
              Text('${selection.modelYear}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.s12),
            if (price != null) ...[
              Text(price.price.format(), style: theme.textTheme.headlineSmall),
              Text(
                'Valor FIPE de ${price.referenceLabel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else
              Text(
                'Valor FIPE indisponível no momento.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: AppSpacing.s8),
            // Wrap rather than Row: two buttons fit side by side at the default
            // text scale and stack at a large one, instead of overflowing.
            Wrap(
              spacing: AppSpacing.s8,
              children: [
                TextButton(
                  onPressed: enabled ? onChange : null,
                  child: const Text('Trocar'),
                ),
                TextButton(
                  onPressed: enabled ? onClear : null,
                  child: const Text('Remover'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The affordance that opens the picker when no selection was made in this
/// session.
///
/// [alreadyLinked] is the edit case: the vehicle carries a catalogue link from
/// when it was registered, but this form has not fetched it. Saying so costs
/// nothing and is honest — the alternative is either a request on every form
/// open or a screen that implies the vehicle was typed by hand.
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: alreadyLinked
                ? 'Trocar na tabela FIPE'
                : 'Buscar na tabela FIPE',
            variant: AppButtonVariant.secondary,
            onPressed: enabled ? onPressed : null,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            alreadyLinked
                ? 'Este veículo foi cadastrado pela tabela FIPE. '
                      'Buscar de novo substitui marca, modelo, ano e combustível.'
                : 'Preenche marca, modelo, ano e combustível para você. '
                      'Também dá para digitar tudo à mão.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
