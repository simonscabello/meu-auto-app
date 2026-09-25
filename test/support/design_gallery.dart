import 'package:flutter/material.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/theme/app_colors.dart';
import 'package:meu_auto/core/theme/app_motion.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_choice_row.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_detail_header.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_expandable_group.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_fact_row.dart';
import 'package:meu_auto/shared/widgets/app_facts_strip.dart';
import 'package:meu_auto/shared/widgets/app_folded_section.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_overflow_menu.dart';
import 'package:meu_auto/shared/widgets/app_plate_chip.dart';
import 'package:meu_auto/shared/widgets/app_progress_bar.dart';
import 'package:meu_auto/shared/widgets/app_quick_action.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_segmented.dart';
import 'package:meu_auto/shared/widgets/app_setting_row.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_status_chip.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';
import 'package:meu_auto/shared/widgets/app_avatar.dart';
import 'package:meu_auto/shared/widgets/app_switch_row.dart';
import 'package:meu_auto/shared/widgets/app_tab_header.dart';
import 'package:meu_auto/shared/widgets/app_wordmark.dart';

/// Catalogue of every design token and base widget, rendered on one page.
///
/// It lives under `test/` and not under `lib/` because no route reaches it:
/// the only thing that builds it is `test/widget_test.dart`, which is what
/// makes it useful — one pump per theme catches an overflow in any of the
/// base widgets before a screen does.
class DesignGallery extends StatefulWidget {
  const DesignGallery({super.key});

  @override
  State<DesignGallery> createState() => _DesignGalleryState();
}

class _DesignGalleryState extends State<DesignGallery> {
  bool _dark = true;
  bool _loadingButton = true;
  bool _switch = true;
  int _segment = 2;
  int _choice = 1;
  final _money = TextEditingController(text: 'R\$\u00A0420,00');
  late final TextEditingController _km = kmController(98450);
  final _liters = TextEditingController(text: '34,7');

  @override
  void dispose() {
    _money.dispose();
    _km.dispose();
    _liters.dispose();
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
              icon: Icon(Icons.build_outlined),
              selectedIcon: Icon(Icons.build),
              label: 'Manutenção',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Histórico',
            ),
          ],
        ),
        body: ListView(
          padding: AppSpacing.screen,
          children: [
            AppSwitchRow(
              title: 'Tema escuro',
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
            const _SectionTitle('Leitura'),
            Text(
              '139.011',
              style: AppTypography.figure(
                size: 44,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              '48.320\u00A0km   R\$\u00A01.234,56',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFeatures: AppTypography.tabular,
              ),
            ),
            const _SectionTitle('Cabeçalho de aba'),
            AppTabHeader(
              title: 'Manutenção',
              contextLabel: 'Prius\u00A0· QAF5G33',
              onContextTap: () {},
              actions: [
                AppOverflowMenu(
                  actions: [
                    AppMenuAction(
                      label: 'Excluir registro',
                      destructive: true,
                      onSelected: () {},
                    ),
                  ],
                ),
              ],
            ),
            const _SectionTitle('Ícones'),
            const Wrap(
              spacing: AppSpacing.s12,
              runSpacing: AppSpacing.s12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppIconWell(
                  icon: Icons.build_outlined,
                  size: AppIconWellSize.s,
                ),
                AppIconWell(icon: Icons.build_outlined),
                AppIconWell(
                  icon: Icons.build_outlined,
                  size: AppIconWellSize.l,
                ),
                AppIconWell(
                  icon: Icons.check_circle_outline,
                  size: AppIconWellSize.l,
                  tone: AppIconWellTone.accent,
                ),
                AppIconWell(
                  icon: Icons.error_outline,
                  size: AppIconWellSize.l,
                  tone: AppIconWellTone.status,
                  status: AppStatus.vencido,
                ),
                AppIconWell(
                  icon: Icons.schedule_outlined,
                  size: AppIconWellSize.l,
                  tone: AppIconWellTone.status,
                  status: AppStatus.venceEmBreve,
                ),
                AppIconWell(
                  icon: Icons.history_outlined,
                  size: AppIconWellSize.xl,
                ),
              ],
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
                  label: 'Terciário',
                  variant: AppButtonVariant.tertiary,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'Com ícone',
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'Salvando',
                  loading: _loadingButton,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'Alternar carregamento',
                  variant: AppButtonVariant.tertiary,
                  onPressed: () =>
                      setState(() => _loadingButton = !_loadingButton),
                ),
              ],
            ),
            const _SectionTitle('Ações rápidas'),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: AppQuickAction(
                      icon: Icons.local_gas_station_outlined,
                      label: 'Abastecer',
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: AppQuickAction(
                      icon: Icons.build_outlined,
                      label: 'Registrar manutenção',
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            AppQuickAction(
              icon: Icons.build_outlined,
              label: 'Registrar manutenção',
              wide: true,
              onTap: () {},
            ),
            const _SectionTitle('Progresso'),
            const AppProgressBar(value: 0.62),
            const SizedBox(height: AppSpacing.s8),
            AppProgressBar(
              value: 1,
              color: statusColors(
                AppStatus.vencido,
                theme.brightness,
              ).foreground,
            ),
            const _SectionTitle('Cabeçalho de detalhe'),
            const AppDetailHeader(
              title: 'IPVA 2026',
              subtitle: 'Vencimento em 15/03/2026',
              status: AppStatus.venceEmBreve,
              phrase: 'Vence em 12 dias',
            ),
            const SizedBox(height: AppSpacing.s16),
            const AppFactsStrip(
              facts: [
                AppFact(label: 'Total', value: 'R\$\u00A0246,55'),
                AppFact(label: 'Litros', value: '39,83', unit: 'L'),
                AppFact(label: 'Consumo', value: '17,2', unit: 'km/L'),
              ],
            ),
            const _SectionTitle('Placa'),
            const Align(
              alignment: Alignment.centerLeft,
              child: AppPlateChip(plate: 'QAF5G33'),
            ),
            const _SectionTitle('Avatar'),
            // Without a photo, the initial; a photo that fails to load falls
            // back to the same initial rather than a broken image.
            const Row(
              children: [
                AppAvatar(name: 'Simon', size: 36),
                SizedBox(width: 12),
                AppAvatar(name: 'Simon', size: 64),
                SizedBox(width: 12),
                AppAvatar(
                  name: 'Ana',
                  size: 64,
                  photoUrl: 'https://invalid.test/foto.jpg',
                ),
              ],
            ),
            const _SectionTitle('Cabeçalho de seção'),
            AppSectionHeader(
              title: 'Próximos cuidados',
              emphasis: AppSectionEmphasis.title,
              actionLabel: 'Ver todos',
              onAction: () {},
            ),
            AppSectionHeader(
              title: 'Manutenção',
              count: 3,
              actionLabel: 'Ver tudo',
              onAction: () {},
            ),
            const _SectionTitle('Linhas de lista'),
            const AppListRow(
              icon: Icons.oil_barrel_outlined,
              title: 'Troca de óleo do motor',
              subtitle: 'Em dia\u00A0· próxima em 11\u00A0set',
            ),
            const AppRowDivider(),
            AppListRow(
              icon: Icons.settings_outlined,
              title: 'Correia dentada',
              subtitle: 'Venceu há 40 dias',
              status: AppStatus.vencido,
              onTap: () {},
              showChevron: true,
            ),
            const AppRowDivider(),
            // The figure on the name's line, the state line the full width
            // under both (AppRowBody).
            AppListRow(
              icon: Icons.local_gas_station_outlined,
              title: 'Gasolina · 37,65 L',
              subtitle: '5 set · Sem consumo ainda',
              value: 'R\$ 240,58',
              strongValue: true,
              onTap: () {},
              showChevron: true,
            ),
            const AppRowDivider(),
            AppListRow(
              icon: Icons.tire_repair_outlined,
              title: 'Calibrar os pneus',
              subtitle: 'Vence em 3 dias',
              status: AppStatus.venceEmBreve,
              trailing: AppButton(
                label: 'Feito',
                variant: AppButtonVariant.secondary,
                compact: true,
                onPressed: () {},
              ),
            ),
            const _SectionTitle('Grupos'),
            AppGroup(
              title: 'Documentos e prazos',
              footnote: 'Inclui IPVA, licenciamento e seguro',
              children: [
                AppListRow(
                  icon: Icons.receipt_long_outlined,
                  title: 'IPVA 2026',
                  subtitle: 'Pago em 12\u00A0fev',
                  onTap: () {},
                  showChevron: true,
                ),
                AppListRow(
                  icon: Icons.description_outlined,
                  title: 'Licenciamento 2026',
                  subtitle: 'Vence em 20 dias',
                  onTap: () {},
                  showChevron: true,
                ),
                AppListRow(
                  icon: Icons.add,
                  iconTone: AppIconWellTone.accent,
                  title: 'Registrar seguro',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            AppGroup(
              dividerIndent: 0,
              children: [
                const AppFactRow(
                  label: 'Última vez',
                  value: '12/02/2026\u00A0· 98.450\u00A0km',
                ),
                AppFactRow(
                  label: 'Intervalo',
                  value: 'a cada 10.000\u00A0km ou 12 meses',
                  onTap: () {},
                ),
                const AppFactRow(
                  label: 'Placa',
                  value: 'QAF5G33',
                  inline: true,
                ),
              ],
            ),
            const _SectionTitle('Grupo que expande'),
            AppExpandableGroup(
              title: 'Em dia',
              count: 12,
              explanation: 'Ficam no histórico e nunca vencem.',
              initiallyOpen: true,
              children: [
                AppListRow(
                  icon: Icons.air_outlined,
                  title: 'Filtro de ar',
                  subtitle: 'Faltam 8.000\u00A0km',
                  onTap: () {},
                  showChevron: true,
                ),
                const AppListRow(
                  icon: Icons.bolt_outlined,
                  title: 'Velas',
                  subtitle: 'Faltam 21.000\u00A0km',
                  value: 'R\$\u00A0320,00',
                  strongValue: true,
                ),
              ],
            ),
            const _SectionTitle('Configurações'),
            AppGroup(
              dividerIndent: 44,
              children: [
                AppSettingRow(
                  label: 'Nome',
                  icon: Icons.badge_outlined,
                  value: 'Simon Scabello',
                  onTap: () {},
                ),
                const AppSettingRow(
                  label: 'E-mail',
                  icon: Icons.mail_outline,
                  value: 'simon@example.com',
                ),
                AppSettingRow(
                  label: 'Sair',
                  icon: Icons.logout_outlined,
                  destructive: true,
                  onTap: () {},
                ),
              ],
            ),
            const _SectionTitle('Segmentado e escolha'),
            AppSegmented<int>(
              value: _segment,
              onChanged: (value) => setState(() => _segment = value),
              options: const [
                AppSegmentedOption(value: 0, label: 'Claro'),
                AppSegmentedOption(value: 1, label: 'Escuro'),
                AppSegmentedOption(value: 2, label: 'Sistema'),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            AppGroup(
              dividerIndent: 0,
              children: [
                AppChoiceRow<int>(
                  value: 0,
                  groupValue: _choice,
                  label: 'Toda semana',
                  onChanged: (value) => setState(() => _choice = value),
                ),
                AppChoiceRow<int>(
                  value: 1,
                  groupValue: _choice,
                  label: 'A cada 15 dias',
                  onChanged: (value) => setState(() => _choice = value),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            AppSwitchRow(
              title: 'Tanque cheio',
              subtitle: 'É o que permite calcular o consumo',
              value: _switch,
              onChanged: (value) => setState(() => _switch = value),
            ),
            const _SectionTitle('Seção dobrada'),
            const AppFoldedSection(
              title: 'Dados do documento',
              subtitle: 'Renavam e chassi, se você tiver o CRLV à mão.',
              children: [Text('conteúdo')],
            ),
            const _SectionTitle('Superfícies'),
            const AppSurface(
              variant: AppSurfaceVariant.grouped,
              child: Text('grouped'),
            ),
            const SizedBox(height: AppSpacing.s8),
            const AppSurface(
              variant: AppSurfaceVariant.raised,
              child: Text('raised'),
            ),
            const SizedBox(height: AppSpacing.s8),
            const AppSurface(
              variant: AppSurfaceVariant.sunken,
              child: Text('sunken'),
            ),
            const _SectionTitle('Marca'),
            const Align(
              alignment: Alignment.centerLeft,
              child: AppWordmark(size: AppWordmarkSize.small),
            ),
            const SizedBox(height: AppSpacing.s12),
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
            AppKmField(controller: _km, helperText: 'Atual: 98.450\u00A0km'),
            const SizedBox(height: AppSpacing.s12),
            AppLitersField(controller: _liters),
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
            const AppSurface(
              variant: AppSurfaceVariant.grouped,
              child: AppEmptyState(
                icon: Icons.directions_car_outlined,
                title: 'Cadastre seu primeiro veículo',
                message:
                    'Com o carro cadastrado, os prazos e o histórico ficam neste app.',
                actionLabel: 'Cadastrar',
                onAction: _noop,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            const AppSurface(
              variant: AppSurfaceVariant.grouped,
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
    final tones = AppTones.of(context);
    final entries = <(String, Color, Color)>[
      ('primary', scheme.primary, scheme.onPrimary),
      ('primaryContainer', scheme.primaryContainer, scheme.onPrimaryContainer),
      ('secondary', scheme.secondary, scheme.onSecondary),
      ('tertiary', scheme.tertiary, scheme.onTertiary),
      ('surface', scheme.surface, scheme.onSurface),
      ('surfaceContainerLow', scheme.surfaceContainerLow, scheme.onSurface),
      ('surfaceContainerHigh', scheme.surfaceContainerHigh, scheme.onSurface),
      ('error', scheme.error, scheme.onError),
      ('errorContainer', scheme.errorContainer, scheme.onErrorContainer),
      ('surfaceContainer', scheme.surfaceContainer, scheme.onSurface),
      ('stroke', tones.stroke, scheme.onSurface),
      ('success', tones.success, scheme.surface),
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
      width: 150,
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
