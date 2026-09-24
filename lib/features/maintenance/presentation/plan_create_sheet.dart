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
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

/// Creating a plan is naming the catalogue item. Intervals default to the
/// catalogue's, so the short path is pick and save.
class PlanCreateSheet extends ConsumerStatefulWidget {
  const PlanCreateSheet({super.key, required this.vehicleId});

  final String vehicleId;

  static Future<void> show(BuildContext context, {required String vehicleId}) {
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => PlanCreateSheet(vehicleId: vehicleId),
    );
  }

  @override
  ConsumerState<PlanCreateSheet> createState() => _PlanCreateSheetState();
}

class _PlanCreateSheetState extends ConsumerState<PlanCreateSheet> {
  final _query = TextEditingController();
  MaintenanceItem? _selected;
  String? _createId;
  String? _createIdItem;
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

    // One id per item chosen: a retry of the same choice replays the same
    // request, and picking another item is another request.
    final repository = ref.read(maintenancePlanRepositoryProvider);
    if (_createId == null || _createIdItem != item.id) {
      _createId = repository.nextId();
      _createIdItem = item.id;
    }
    try {
      await repository.create(
        vehicleId: widget.vehicleId,
        maintenanceItemId: item.id,
        id: _createId,
      );
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
    // The list INCLUDING what the vehicle does not have. An item already ruled
    // out must not reappear here as an ordinary choice — the place to bring one
    // back is the profile screen, where the reason is visible.
    final plans = ref.watch(
      maintenancePlansWithHiddenProvider(widget.vehicleId),
    );
    final listed = plans.valueOrNull;
    final taken = <String>{
      if (listed != null)
        for (final plan in listed) plan.maintenanceItemId,
    };

    return AppSheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetHeader(
            title: 'Acompanhar outro item',
            subtitle: 'Vamos usar o intervalo sugerido. Você ajusta depois.',
            closable: false,
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
          const SizedBox(height: AppSpacing.s8),
          Expanded(child: _body(catalogue, taken)),
          const SizedBox(height: AppSpacing.s8),
          AppButton(
            label: _offline ? 'Tentar de novo' : 'Salvar',
            loading: _submitting,
            onPressed: _selected == null || _submitting ? null : _submit,
            expanded: true,
          ),
        ],
      ),
    );
  }

  Widget _body(AsyncValue<List<MaintenanceItem>> catalogue, Set<String> taken) {
    final theme = Theme.of(context);
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
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: AppSectionHeader(
              title: MaintenanceItemKind.maintenance.sectionTitle,
            ),
          ),
          for (var i = 0; i < maintenance.length; i++) ...[
            if (i > 0) const AppRowDivider(),
            _tile(context, maintenance[i]),
          ],
        ],
        if (care.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s16),
            child: AppSectionHeader(
              title: MaintenanceItemKind.care.sectionTitle,
            ),
          ),
          for (var i = 0; i < care.length; i++) ...[
            if (i > 0) const AppRowDivider(),
            _tile(context, care[i]),
          ],
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, MaintenanceItem item) {
    final theme = Theme.of(context);
    final selected = selectedId == item.id;
    return Semantics(
      button: true,
      selected: selected,
      label: item.name,
      excludeSemantics: true,
      child: AppListRowShell(
        onTap: onSelect == null ? null : () => onSelect!(item),
        child: Row(
          children: [
            AppIconWell(
              icon: maintenanceIconFor(item.slug),
              tone: selected ? AppIconWellTone.accent : AppIconWellTone.neutral,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                item.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 20, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
