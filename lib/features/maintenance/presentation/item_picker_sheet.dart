import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// Multi-select catalogue. Search, grouped by kind, already-chosen items
/// marked, cap of 20, and a way out for anything the catalogue does not name.
class ItemPickerSheet extends ConsumerStatefulWidget {
  const ItemPickerSheet({super.key, required this.selected});

  final List<MaintenanceItem> selected;

  static Future<List<MaintenanceItem>?> show(
    BuildContext context, {
    required List<MaintenanceItem> selected,
  }) {
    return showModalBottomSheet<List<MaintenanceItem>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => ItemPickerSheet(selected: selected),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No máximo 20 itens por registro.')),
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
            Text(
              'O que foi feito',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
            const SizedBox(height: AppSpacing.s12),
            Expanded(child: _body(catalogue)),
            const SizedBox(height: AppSpacing.s8),
            AppButton(
              label: 'Criar item personalizado',
              variant: AppButtonVariant.tertiary,
              onPressed: _createCustom,
            ),
            AppButton(
              label: _selected.isEmpty
                  ? 'Pronto'
                  : 'Pronto (${_selected.length})',
              onPressed: () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AsyncValue<List<MaintenanceItem>> catalogue) {
    return catalogue.when(
      loading: () => const AppSkeletonList(count: 8, itemHeight: 56),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(maintenanceItemsProvider),
      ),
      data: (items) => _GroupedList(
        items: _filtered(items),
        isSelected: _isSelected,
        atCap: _selected.length >= MaintenanceRecordDraft.maxItems,
        onToggle: _toggle,
      ),
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

class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.items,
    required this.isSelected,
    required this.atCap,
    required this.onToggle,
  });

  final List<MaintenanceItem> items;
  final bool Function(String id) isSelected;
  final bool atCap;
  final ValueChanged<MaintenanceItem> onToggle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Nada com esse nome. Tente outra busca.'),
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
    final selected = isSelected(item.id);
    return CheckboxListTile(
      value: selected,
      onChanged: !selected && atCap ? null : (_) => onToggle(item),
      secondary: Icon(maintenanceIconFor(item.slug)),
      title: Text(item.name),
      controlAffinity: ListTileControlAffinity.trailing,
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

class _CustomItemSheet extends ConsumerStatefulWidget {
  const _CustomItemSheet();

  static Future<MaintenanceItem?> show(BuildContext context) {
    return showModalBottomSheet<MaintenanceItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
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
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.s24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Item personalizado', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s16),
            if (_banner != null) ...[
              Text(
                _banner!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
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
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            SegmentedButton<MaintenanceItemKind>(
              segments: const [
                ButtonSegment(
                  value: MaintenanceItemKind.maintenance,
                  label: Text('Manutenção'),
                ),
                ButtonSegment(
                  value: MaintenanceItemKind.care,
                  label: Text('Cuidado'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: _submitting
                  ? null
                  : (next) => setState(() => _kind = next.first),
            ),
            const SizedBox(height: AppSpacing.s16),
            AppButton(label: 'Criar', loading: _submitting, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
