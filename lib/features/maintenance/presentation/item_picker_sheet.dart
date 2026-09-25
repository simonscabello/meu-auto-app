import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_segmented.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

/// Multi-select catalogue. Search, grouped by kind, already-chosen items
/// marked, cap of 20, and a way out for anything the catalogue does not name.
class ItemPickerSheet extends ConsumerStatefulWidget {
  const ItemPickerSheet({
    super.key,
    required this.selected,
    this.lockedItemIds = const {},
    this.title = 'O que foi feito',
    this.hiddenItemIds = const {},
  });

  final List<MaintenanceItem> selected;

  /// Items the car does not have — marked "não usa" on its profile, or ruled
  /// out by its fuel. Left out of the list.
  final Set<String> hiddenItemIds;

  /// Items that are already on the record being added to: shown ticked, and
  /// not untickable. The picker cannot remove a line, so offering a tick that
  /// looks like it would is worse than showing the truth.
  final Set<String> lockedItemIds;

  /// What this picker is for. The default is the record form; adding to a
  /// record that already exists is a different question and says so.
  final String title;

  static Future<List<MaintenanceItem>?> show(
    BuildContext context, {
    required List<MaintenanceItem> selected,
    Set<String> lockedItemIds = const {},
    String title = 'O que foi feito',
    Set<String> hiddenItemIds = const {},
  }) {
    return showAppSheet<List<MaintenanceItem>>(
      context,
      builder: (sheetContext) => ItemPickerSheet(
        selected: selected,
        lockedItemIds: lockedItemIds,
        title: title,
        hiddenItemIds: hiddenItemIds,
      ),
    );
  }

  @override
  ConsumerState<ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends ConsumerState<ItemPickerSheet> {
  final _query = TextEditingController();
  late List<MaintenanceItem> _selected;

  @override
  void initState() {
    super.initState();
    _selected = [...widget.selected];
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _isSelected(String id) {
    for (final item in _selected) {
      if (item.id == id) return true;
    }
    return false;
  }

  void _toggle(MaintenanceItem item) {
    if (_isSelected(item.id)) {
      setState(() {
        _selected = [
          for (final current in _selected)
            if (current.id != item.id) current,
        ];
      });
      return;
    }
    if (_selected.length >= MaintenanceRecordDraft.maxItems) {
      showAppSnackBar(
        ScaffoldMessenger.of(context),
        message: 'No máximo 20 itens por registro.',
      );
      return;
    }
    setState(() => _selected = [..._selected, item]);
  }

  Future<void> _createCustom() async {
    final created = await _CustomItemSheet.show(context);
    if (created == null || !mounted) return;
    ref.invalidate(maintenanceItemsProvider);
    if (_isSelected(created.id)) return;
    if (_selected.length >= MaintenanceRecordDraft.maxItems) return;
    setState(() => _selected = [..._selected, created]);
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(maintenanceItemsProvider);

    return AppSheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(title: widget.title, closable: false),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Buscar',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          Expanded(child: _body(catalogue)),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Criar item personalizado',
              icon: Icons.add,
              variant: AppButtonVariant.tertiary,
              onPressed: _createCustom,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          AppButton(
            label: _selected.isEmpty
                ? 'Pronto'
                : 'Pronto (${_selected.length})',
            onPressed: () => Navigator.of(context).pop(_selected),
            expanded: true,
          ),
        ],
      ),
    );
  }

  Widget _body(AsyncValue<List<MaintenanceItem>> catalogue) {
    return catalogue.when(
      // Clipped rather than laid out whole: eight rows are taller than the
      // room a sheet leaves under its search field on a small phone.
      loading: () => const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: AppSkeletonList(count: 8, itemHeight: 56),
      ),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(maintenanceItemsProvider),
      ),
      data: (items) {
        final atCap =
            _selected.length + widget.lockedItemIds.length >=
            MaintenanceRecordDraft.maxItems;
        return CatalogueItemList(
          items: _filtered(items),
          emptyMessage: 'Nenhum item com esse nome.',
          rowBuilder: (item) {
            final locked = widget.lockedItemIds.contains(item.id);
            final selected = locked || _isSelected(item.id);
            return _PickRow(
              key: ValueKey(item.id),
              item: item,
              selected: selected,
              locked: locked,
              enabled: !locked && (selected || !atCap),
              onToggle: _toggle,
            );
          },
        );
      },
    );
  }

  List<MaintenanceItem> _filtered(List<MaintenanceItem> items) {
    final needle = _query.text.trim().toLowerCase();
    return [
      for (final item in items)
        if (!widget.hiddenItemIds.contains(item.id) &&
            (needle.isEmpty || item.name.toLowerCase().contains(needle)))
          item,
    ];
  }
}

/// The catalogue the way the app splits it — maintenance first, then everyday
/// care — as one group each, for the two sheets that choose from it.
///
/// A group per kind rather than rows straight on the sheet: thirty items
/// under two quiet labels read as one column, and the surface is what says
/// where one kind ends and the next begins.
class CatalogueItemList extends StatelessWidget {
  const CatalogueItemList({
    super.key,
    required this.items,
    required this.rowBuilder,
    required this.emptyMessage,
  });

  final List<MaintenanceItem> items;

  /// One row per item. Return a [GroupedRow] so its ink reaches the edges.
  final Widget Function(MaintenanceItem item) rowBuilder;

  /// Said in place of the list when there is nothing to show.
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final maintenance = [
      for (final item in items)
        if (item.kind != MaintenanceItemKind.care) item,
    ];
    final care = [
      for (final item in items)
        if (item.kind == MaintenanceItemKind.care) item,
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      children: [
        AppGroup(
          title: MaintenanceItemKind.maintenance.sectionTitle,
          emphasis: AppSectionEmphasis.label,
          children: [for (final item in maintenance) rowBuilder(item)],
        ),
        if (maintenance.isNotEmpty && care.isNotEmpty)
          const SizedBox(height: AppSpacing.s24),
        AppGroup(
          title: MaintenanceItemKind.care.sectionTitle,
          emphasis: AppSectionEmphasis.label,
          children: [for (final item in care) rowBuilder(item)],
        ),
      ],
    );
  }
}

/// One catalogue item that can be ticked. An item already on the record is
/// ticked and does not answer a tap.
class _PickRow extends StatelessWidget with GroupedRow {
  const _PickRow({
    super.key,
    required this.item,
    required this.selected,
    required this.locked,
    required this.enabled,
    required this.onToggle,
  });

  final MaintenanceItem item;
  final bool selected;
  final bool locked;
  final bool enabled;
  final ValueChanged<MaintenanceItem> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      checked: selected,
      enabled: enabled,
      label: locked ? '${item.name}. Já está neste registro' : item.name,
      excludeSemantics: true,
      child: AppListRowShell(
        onTap: enabled ? () => onToggle(item) : null,
        child: Row(
          children: [
            AppIconWell(
              icon: maintenanceIconFor(item.slug),
              tone: selected ? AppIconWellTone.accent : AppIconWellTone.neutral,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: enabled
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Já está neste registro',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            // The whole row is the target, so the box keeps only its drawn
            // size — its own 48dp padding made every row half again as tall.
            Checkbox(
              value: selected,
              onChanged: enabled ? (_) => onToggle(item) : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomItemSheet extends ConsumerStatefulWidget {
  const _CustomItemSheet();

  static Future<MaintenanceItem?> show(BuildContext context) {
    return showAppSheet<MaintenanceItem>(
      context,
      builder: (sheetContext) => const _CustomItemSheet(),
    );
  }

  @override
  ConsumerState<_CustomItemSheet> createState() => _CustomItemSheetState();
}

class _CustomItemSheetState extends ConsumerState<_CustomItemSheet> {
  final _name = TextEditingController();
  MaintenanceItemKind _kind = MaintenanceItemKind.maintenance;
  bool _submitting = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _banner = null;
      _fieldErrors = {};
    });
    try {
      final created = await ref
          .read(maintenanceItemRepositoryProvider)
          .createCustom(name: _name.text, kind: _kind);
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _fieldErrors = ApiFormErrors.fieldsOf(failure);
        _banner = ApiFormErrors.bannerOf(failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      children: [
        const AppSheetHeader(
          title: 'Item personalizado',
          subtitle: 'Para algo que o catálogo não tem',
          closable: false,
        ),
        const SizedBox(height: AppSpacing.s16),
        if (_banner != null) AuthFormBanner(message: _banner!),
        TextField(
          controller: _name,
          enabled: !_submitting,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitting ? null : _submit(),
          maxLength: 120,
          decoration: InputDecoration(
            labelText: 'Nome',
            counterText: '',
            errorText: _fieldErrors['name'],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        AppSegmented<MaintenanceItemKind>(
          value: _kind,
          enabled: !_submitting,
          onChanged: (next) => setState(() => _kind = next),
          options: const [
            AppSegmentedOption(
              value: MaintenanceItemKind.maintenance,
              label: 'Manutenção',
            ),
            AppSegmentedOption(
              value: MaintenanceItemKind.care,
              label: 'Cuidado',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s24),
        AppButton(
          label: 'Criar item',
          loading: _submitting,
          onPressed: _submit,
          expanded: true,
        ),
      ],
    );
  }
}
