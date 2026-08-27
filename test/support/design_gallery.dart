import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_colors.dart';
import 'package:meu_auto/core/theme/app_motion.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_metric.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_status_chip.dart';
import 'package:meu_auto/shared/widgets/app_wordmark.dart';

/// Catalogue of every design token and base widget, rendered on one page.
///
/// It lives under `test/` and not under `lib/` because no route reaches it:
/// the only thing that builds it is `test/widget_test.dart`, which is what
/// makes it useful — one pump per theme catches an overflow in any of the
/// nine base widgets before a screen does.
class DesignGallery extends StatefulWidget {
  const DesignGallery({super.key});

  @override
  State<DesignGallery> createState() => _DesignGalleryState();
}

class _DesignGalleryState extends State<DesignGallery> {
  bool _dark = false;
  bool _loadingButton = true;
  final _money = TextEditingController(text: 'R\$ 420,00');
  late final TextEditingController _km = kmController(98450);

  @override
  void dispose() {
    _money.dispose();
    _km.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _dark ? AppTheme.dark : AppTheme.light;
    return Theme(
      data: theme,
      child: AppScaffold(
        title: 'Galeria de design',
        actions: [
          IconButton(
            tooltip: _dark ? 'Tema claro' : 'Tema escuro',
            onPressed: () => setState(() => _dark = !_dark),
            icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
        onRefresh: () async {
          await Future<void>.delayed(AppMotion.medium);
        },
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Início',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon: Icon(Icons.directions_car),
              label: 'Veículos',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Conta',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tema escuro'),
              value: _dark,
              onChanged: (value) => setState(() => _dark = value),
            ),
            const _SectionTitle('Cores'),
            const _ColorSwatches(),
            const _SectionTitle('Estados de domínio'),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                for (final status in AppStatus.values)
                  AppStatusChip(status: status),
              ],
            ),
            const _SectionTitle('Espaçamento'),
            const _SpacingScale(),
            const _SectionTitle('Raio'),
            const _RadiusScale(),
            const _SectionTitle('Tipografia'),
            const _TypeScale(),
            const _SectionTitle('Números tabulares'),
            Text(
              '48.320 km   R\$ 1.234,56',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFeatures: AppTypography.tabular,
              ),
            ),
            const _SectionTitle('Botões'),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                AppButton(label: 'Primário', onPressed: () {}),
                const AppButton(
                  label: 'Secundário',
                  variant: AppButtonVariant.secondary,
                  onPressed: _noop,
                ),
                const AppButton(
                  label: 'Excluir',
                  variant: AppButtonVariant.destructive,
                  onPressed: _noop,
                ),
                AppButton(
                  label: 'Salvando',
                  loading: _loadingButton,
                  onPressed: () {},
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _loadingButton = !_loadingButton),
                  child: const Text('Alternar carregamento'),
                ),
              ],
            ),
            const _SectionTitle('Card e métrica'),
            const AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: AppMetric(
                      value: '48.320',
                      unit: 'km',
                      label: 'Quilometragem atual',
                    ),
                  ),
                  SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: AppMetric(
                      value: 'R\$ 1.280,00',
                      label: 'Custo registrado',
                    ),
                  ),
                ],
              ),
            ),
            const _SectionTitle('Cabeçalho de seção'),
            AppSectionHeader(
              title: 'Manutenção',
              actionLabel: 'Ver tudo',
              onAction: () {},
            ),
            const _SectionTitle('Marca'),
            const Align(alignment: Alignment.centerLeft, child: AppWordmark()),
            const SizedBox(height: AppSpacing.s12),
            const Align(
              alignment: Alignment.centerLeft,
              child: AppWordmark(size: AppWordmarkSize.large),
            ),
            const _SectionTitle('Campos'),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Placa',
                hintText: 'ABC1D23',
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            AppMoneyField(controller: _money, label: 'Valor total'),
            const SizedBox(height: AppSpacing.s12),
            AppKmField(controller: _km, helperText: 'Atual: 98.450 km'),
            const SizedBox(height: AppSpacing.s12),
            AppDateField(value: CivilDate.todayLocal(), onPick: _noop),
            const SizedBox(height: AppSpacing.s12),
            const AppDateField(value: null, onPick: _noop),
            const SizedBox(height: AppSpacing.s12),
            Wrap(
              spacing: AppSpacing.s8,
              children: [
                FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alterações salvas.')),
                    );
                  },
                  child: const Text('SnackBar'),
                ),
                OutlinedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (sheetContext) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.s24),
                          child: Text('Folha inferior'),
                        );
                      },
                    );
                  },
                  child: const Text('Bottom sheet'),
                ),
              ],
            ),
            const _SectionTitle('Esqueleto'),
            const AppSkeletonList(count: 3),
            const SizedBox(height: AppSpacing.s24),
            const AppCard(
              child: AppEmptyState(
                title: 'Cadastre seu primeiro veículo',
                message:
                    'Com o carro cadastrado, os prazos e o histórico ficam neste app.',
                actionLabel: 'Cadastrar',
                onAction: _noop,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            const AppCard(
              child: AppErrorState(
                message: 'Ocorreu um erro inesperado. Tente novamente.',
                onRetry: _noop,
              ),
            ),
            const SizedBox(height: AppSpacing.s48),
          ],
        ),
      ),
    );
  }
}

void _noop() {}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.s32,
        bottom: AppSpacing.s12,
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final entries = <(String, Color, Color)>[
      ('primary', scheme.primary, scheme.onPrimary),
      ('primaryContainer', scheme.primaryContainer, scheme.onPrimaryContainer),
      ('secondary', scheme.secondary, scheme.onSecondary),
      ('surface', scheme.surface, scheme.onSurface),
      ('surfaceContainer', scheme.surfaceContainer, scheme.onSurface),
      ('error', scheme.error, scheme.onError),
      ('outline', scheme.outline, scheme.surface),
    ];
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: [
        for (final entry in entries)
          _Swatch(name: entry.$1, background: entry.$2, foreground: entry.$3),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.background,
    required this.foreground,
  });

  final String name;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(AppSpacing.s8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.borderS,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        name,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}

class _SpacingScale extends StatelessWidget {
  const _SpacingScale();

  static const _steps = [
    AppSpacing.s4,
    AppSpacing.s8,
    AppSpacing.s12,
    AppSpacing.s16,
    AppSpacing.s20,
    AppSpacing.s24,
    AppSpacing.s32,
    AppSpacing.s40,
    AppSpacing.s48,
  ];

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (final size in _steps)
          Column(
            children: [
              Container(width: size, height: size, color: color),
              const SizedBox(height: AppSpacing.s4),
              Text('$size', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}

class _RadiusScale extends StatelessWidget {
  const _RadiusScale();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _RadiusBox(
          label: 's ${AppRadius.s}',
          radius: AppRadius.borderS,
          color: scheme.primaryContainer,
        ),
        const SizedBox(width: AppSpacing.s12),
        _RadiusBox(
          label: 'm ${AppRadius.m}',
          radius: AppRadius.borderM,
          color: scheme.primaryContainer,
        ),
        const SizedBox(width: AppSpacing.s12),
        _RadiusBox(
          label: 'l ${AppRadius.l}',
          radius: AppRadius.borderL,
          color: scheme.primaryContainer,
        ),
      ],
    );
  }
}

class _RadiusBox extends StatelessWidget {
  const _RadiusBox({
    required this.label,
    required this.radius,
    required this.color,
  });

  final String label;
  final BorderRadius radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: color, borderRadius: radius),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final samples = <(String, TextStyle?)>[
      ('displaySmall', theme.displaySmall),
      ('headlineLarge', theme.headlineLarge),
      ('headlineMedium', theme.headlineMedium),
      ('titleLarge', theme.titleLarge),
      ('titleMedium', theme.titleMedium),
      ('bodyLarge', theme.bodyLarge),
      ('bodyMedium', theme.bodyMedium),
      ('bodySmall', theme.bodySmall),
      ('labelLarge', theme.labelLarge),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sample in samples)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: Text('${sample.$1} — Meu Auto 0123456789', style: sample.$2),
          ),
      ],
    );
  }
}
