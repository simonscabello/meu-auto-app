import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

/// Creating a plan is naming the catalogue item. Intervals default to the
/// catalogue's, so the short path is pick and save.
class PlanCreateSheet extends ConsumerStatefulWidget {
  const PlanCreateSheet({super.key, required this.vehicleId});

  final String vehicleId;

  static Future<void> show(BuildContext context, {required String vehicleId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => PlanCreateSheet(vehicleId: vehicleId),
    );
  }

  @override
  ConsumerState<PlanCreateSheet> createState() => _PlanCreateSheetState();
}

class _PlanCreateSheetState extends ConsumerState<PlanCreateSheet> {
  final _query = TextEditingController();
  MaintenanceItem? _selected;
  bool _submitting = false;
  bool _offline = false;
  String? _banner;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final item = _selected;
    if (item == null) return;

    setState(() {
      _submitting = true;
      _banner = null;
      _offline = false;
    });

    try {
      await ref
          .read(maintenancePlanRepositoryProvider)
          .create(vehicleId: widget.vehicleId, maintenanceItemId: item.id);
      invalidateAfterPlanWrite(ref, widget.vehicleId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      showAppSnackBar(messenger, message: 'Plano criado.');
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _banner = ApiFormErrors.bannerOf(failure) ?? failure.message;
        _offline = ApiFormErrors.isOffline(failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(maintenanceItemsProvider);
    final plans = ref.watch(maintenancePlansProvider(widget.vehicleId));
    final height = MediaQuery.sizeOf(context).height * 0.85;
    final listed = plans.value;
    final taken = <String>{
      if (listed != null)
        for (final plan in listed) plan.maintenanceItemId,
    };

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
            Text('Novo plano', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Vamos usar o intervalo sugerido, você pode ajustar depois.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            if (_banner != null) AuthFormBanner(message: _banner!),
            TextField(
              controller: _query,
              enabled: !_submitting,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Buscar',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Expanded(child: _body(catalogue, taken)),
            const SizedBox(height: AppSpacing.s8),
            AppButton(
              label: _offline ? 'Tentar de novo' : 'Salvar',
              loading: _submitting,
              onPressed: _selected == null || _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AsyncValue<List<MaintenanceItem>> catalogue, Set<String> taken) {
    return catalogue.when(
      loading: () => const AppSkeletonList(count: 8, itemHeight: 56),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(maintenanceItemsProvider),
      ),
      data: (items) {
        final available = [
          for (final item in items)
            if (!taken.contains(item.id)) item,
        ];
        final visible = _filtered(available);
        if (visible.isEmpty) {
          return Center(
            child: Text(
              _query.text.trim().isEmpty
                  ? 'Todos os itens do catálogo já têm um plano.'
                  : 'Nada com esse nome. Tente outra busca.',
            ),
          );
        }
        return _GroupedPicker(
          items: visible,
          selectedId: _selected?.id,
          onSelect: _submitting
              ? null
              : (item) => setState(() => _selected = item),
        );
      },
    );
  }

  List<MaintenanceItem> _filtered(List<MaintenanceItem> items) {
    final needle = _query.text.trim().toLowerCase();
    if (needle.isEmpty) return items;
    return [
      for (final item in items)
        if (item.name.toLowerCase().contains(needle)) item,
    ];
  }
}

class _GroupedPicker extends StatelessWidget {
  const _GroupedPicker({
    required this.items,
    required this.selectedId,
    required this.onSelect,
  });

  final List<MaintenanceItem> items;
  final String? selectedId;
  final ValueChanged<MaintenanceItem>? onSelect;

  @override
  Widget build(BuildContext context) {
    final maintenance = [
      for (final item in items)
        if (item.kind != MaintenanceItemKind.care) item,
    ];
    final care = [
      for (final item in items)
        if (item.kind == MaintenanceItemKind.care) item,
    ];

    return ListView(
      children: [
        if (maintenance.isNotEmpty) ...[
          _SectionTitle(MaintenanceItemKind.maintenance.sectionTitle),
          for (final item in maintenance) _tile(item),
        ],
        if (care.isNotEmpty) ...[
          _SectionTitle(MaintenanceItemKind.care.sectionTitle),
          for (final item in care) _tile(item),
        ],
      ],
    );
  }

  Widget _tile(MaintenanceItem item) {
    final selected = selectedId == item.id;
    return ListTile(
      selected: selected,
      onTap: onSelect == null ? null : () => onSelect!(item),
      leading: Icon(maintenanceIconFor(item.slug)),
      title: Text(item.name),
      trailing: selected ? const Icon(Icons.check) : null,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.s8, 0, AppSpacing.s4),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
