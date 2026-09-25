# Design system

Segunda versão, de 25/09/2026. Substitui a de 24/09 ("painel de instrumentos
à noite": fundo navy com degradê e luz, ciano elétrico, poços de ícone em
toda linha). Este arquivo é a referência do que existe e de como usar; a
identidade dos assets nativos (ícone, splash) continua em
`IDENTIDADE-VISUAL.md`.

A régua de qualidade desta versão foi outro app do dono, o Pauta — não a
aparência dele (outra marca, outro domínio), mas as decisões: uma superfície
por grupo, ícone sem enfeite, um botão cheio por tela, ação rara no ⋮,
cabeçalho de detalhe sem caixa, estados vazios que dizem o que fazer, textos
curtos.

## A ideia

O carro do dono, não um painel de frota. Um app escuro, calmo e objetivo:

- **Grafite, não navy.** Neutros carvão com um traço de azul frio; a página é
  um tom liso, sem degradê e sem luz. Os cartões ficam um degrau acima pela
  cor, com um fio de borda — sem sombra.
- **Um azul de sinal** (`#5B9DFF` no escuro, `#1A66DA` no claro) para o que se
  toca, o que está selecionado e o que é "seu" (o carro no cabeçalho). Nada
  mais é azul.
- **Vermelho é vencido, âmbar é perto, verde é feito.** Cada um só aparece
  quando significa isso — no ícone e na frase da linha, nunca num cartão
  inteiro.
- **O elemento automotivo é tipográfico, não fotográfico.** A quilometragem
  em número grande, tabular e apertado; a placa desenhada como placa
  (moldura e a faixa azul do Mercosul). Nenhuma tela depende de foto do
  carro.

O escuro é a identidade e o padrão. O claro é a mesma identidade à luz do dia,
em Perfil > Aparência.

## Tokens (`lib/core/theme`)

| Arquivo | O que guarda |
| --- | --- |
| `app_colors.dart` | `AppColors.dark` / `AppColors.light`. `surface` é a página; `surfaceContainerLow` é o cartão; `surfaceContainer` é campo, barra de navegação e bloco rebaixado; `outline` é borda de controle (3:1); `outlineVariant` é fio decorativo. |
| `app_tones.dart` | `AppTones`: `stroke` (borda do cartão), `strokeStrong`, `divider` (fio entre linhas), `track`, `accentSoft`, `overlayPressed`, `iconWell` (fundo do ícone de estado vazio) e `success*` ("feito"). **Sem degradê, sem glow.** |
| `app_typography.dart` | Inter, escala própria (tracking negativo que cresce com o tamanho). `AppTypography.figure(size:)` para números lidos como leitura (odômetro, totais, faixa de fatos). Algarismos tabulares **só** onde números se alinham — no texto corrido eles alargavam a pontuação ("E - mail"). |
| `app_status_colors.dart` | `AppStatus` + `statusColors`: o único mapa de estado → cor, ícone e palavra. `isLoud` = vencido/vence em breve. |
| `app_spacing.dart` | Escala de 4. `page` (20) é a calha de toda tela, **cabeçalho de aba incluído**; `block` (28) entre blocos; `inset` (16) dentro do cartão; `screen`, `screenHeaded`, `tab` como padding de tela; `buttonHeight` (52) e `compactButtonHeight` (36). |
| `app_radius.dart` | O raio acompanha o tamanho: `xs` 6 (selo, placa), `s` 10 (chip), `control` 12 (botão, campo, segmentado), `m` 16 (cartão, grupo), `tile` 20 (ícone de estado vazio), `l` 24 (folha, diálogo). |
| `app_motion.dart` | Durações e curvas; zera com "reduzir movimento". |
| `app_theme.dart` | O `ThemeData`: tudo o que o Material desenha sozinho. |

Regra: nenhuma cor, raio ou espaçamento literal fora desta pasta.

`test/core/theme/app_theme_test.dart` mede o contraste (4,5:1 para texto,
3:1 para borda de controle) nos dois temas. Mexeu numa cor, rode.

## Estrutura de tela

- **Aba** (Início, Manutenção, Documentos, Histórico): sem `AppBar`. O corpo
  começa com `VehicleTabHeader` (título grande, a linha do carro em azul que
  abre o seletor de veículo, ações da aba e o avatar do Perfil). Conteúdo com
  `AppSpacing.tab`. Início usa `HomeHeader` (o próprio carro é o título).
- **Tela empilhada** (detalhe, formulário): `AppScaffold(title:)` com título
  curto do *tipo* ("Abastecimento", "IPVA 2026"), ações na barra — lápis para
  editar, `AppOverflowMenu` (⋮) para o raro e o destrutivo.
- **Detalhe**: `AppDetailHeader` (título grande, linha de apoio, selo de
  estado + frase) → `AppFactsStrip` (2–4 fatos numa faixa) → grupos. **Sem
  botões grandes no rodapé**: editar é o lápis, excluir é o ⋮ com
  confirmação.
- **Formulário longo**: `AppFormSection`s (rótulo quieto) → campos →
  `AppFoldedSection` para o opcional → `AppFormFooter` fixo com o botão
  principal. **Formulário curto**: folha (`showAppSheet(isForm: true)` +
  `AppSheetHeader` + `AppSheetBody`).
- **Diálogo só para confirmação** (`confirmAction`); o botão diz o verbo.

## Componentes (`lib/shared/widgets`)

### Superfícies e listas

- `AppSurface` — `none`, `grouped` (o cartão), `raised`, `sunken` (bloco
  rebaixado sem borda: "nada registrado ainda").
- `AppGroup` — título fora, linhas dentro de **um** cartão, fios começando
  onde o texto começa. Lista curta = um grupo; histórico longo = um grupo
  por mês. **Nunca um cartão por item.**
- `AppExpandableGroup` — o grupo que começa fechado ("Em dia 12"): um cartão
  com uma linha, que cresce as linhas dentro dele.
- `GroupedRow` + `AppGroupScope` — uma linha que se declara `GroupedRow`
  recebe o padding do grupo por dentro do alvo de toque, e o realce de toque
  vai de borda a borda do cartão. Toda linha nova de lista deve misturar
  `with GroupedRow` se ela mesma é uma linha (usa `AppListRow` ou
  `AppListRowShell`).
- `AppListRow` — ícone (sem círculo), nome, uma linha de estado, `value` à
  direita (`strongValue` para valores monetários), chevron. `status` tinge
  ícone e frase só quando é vencido/perto.
- `AppListRowShell`, `AppFactRow` (`inline` para fatos curtos),
  `AppSettingRow`, `AppChoiceRow`, `AppSwitchRow`.
- `AppSectionHeader` — `title` (padrão: 16/600, texto) ou `label` (quieto,
  para partes de formulário). Ação à direita em azul, sem botão.
- `AppRowDivider`, `AppPagedFooter`, `groupByMonth`.

### Cabeçalhos e fatos

- `AppTabHeader` / `VehicleTabHeader` — cabeçalho de aba.
- `AppDetailHeader` — sem ícone e sem caixa.
- `AppFactsStrip` + `AppFact` — faixa de 2–4 fatos, colunas iguais.
- `AppStatusChip` — selo com a palavra do estado; só em detalhe.
- `AppPlateChip` — a placa.
- `AppMetric` — número como leitura (use pouco; a faixa de fatos cobre a
  maioria dos casos).

### Ações

- `AppButton` — `primary` (azul cheio, **um por tela**), `secondary` (tonal
  neutro), `tertiary` (texto), `destructive` (tonal vermelho). `compact`
  (36) para dentro de linha.
- `AppQuickAction` — os dois atalhos iguais do Início.
- `AppIconButton`, `AppOverflowMenu` + `AppMenuAction`.
- `ProfileButton` — o avatar com a inicial.

### Formulários e folhas

- `AppFormSection`, `AppFormGap`, `AppFormFooter`, `AppFoldedSection`.
- `AppMoneyField`, `AppKmField`, `AppLitersField`, `AppDateField` — campos com
  máscara; nunca número cru.
- `showAppSheet`, `AppSheetBody`, `AppSheetFrame`, `AppSheetHeader`
  (`trailing` para um link no título).
- `AppSegmented` — escolha entre 2–4 opções.
- `confirmAction`, `AppDiscardGuard`.

### Estados

- `AppEmptyState` — o que devia estar aqui, por quê, e a ação.
- `AppErrorState` — título curto, a mensagem, "Tentar de novo".
- `AppSkeleton` / `AppSkeletonList` — o formato do que vai chegar.
- `showAppSnackBar` (com ✓) / `showAppErrorSnackBar`.

## Texto

Frases curtas e concretas, com o fato: "Venceu há 13 dias", "Vence em 20
dias", "Faltam 2.000 km", "Pago em 12 jan", "Vigente até 28/12/2026",
"Registrado hoje". Nada de "seu veículo merece atenção". Um prazo em dias é
sempre `dueInDaysPhrase` (`core/domain/phrases.dart`) — a mesma frase no
Início e na aba do item.

## Texto grande

Acima de `AppTypography.largeTextScale` (1,3) duas coisas deixam de dividir
a linha — `AppTypography.isLargeText(context)` é a pergunta, uma só:

- o valor de uma linha (`AppListRow.value`, o custo de um registro, o preço
  de um item) e o botão da linha ("Feito") vão **para baixo** do nome, na
  borda do texto. Lado a lado, a 1,6 num telefone de 360dp, "Gastos em 12
  meses" quebrava em "Gasto / s em / 12 / mese / s";
- `AppFactsStrip` e `AppFactRow(inline: true)` empilham rótulo sobre valor;
- os dois atalhos do Início viram duas linhas de largura total, ainda com
  o mesmo peso; "Atualizar" desce para baixo da quilometragem;
- o título da aba encolhe para caber (`FittedBox`), nunca é cortado.

Os rótulos da barra de navegação não crescem: quatro destinos dividem 360dp
e "Manutenção" quebrava em "Manutençã / o". Os ícones carregam a barra, e o
título da aba diz onde se está no tamanho escolhido.

## Iconografia

Material Icons, variante `_outlined`, na cor do texto de apoio. Colorido só
quando é o estado (vermelho/âmbar) ou uma ação (azul). `maintenanceIconFor`
mapeia o item do catálogo para um ícone; o Início usa o mesmo ícone do item
nos avisos.

## Galeria

`test/support/design_gallery.dart` renderiza tokens e componentes numa página
e `test/widget_test.dart` a bombeia nos dois temas. Componente novo entra na
galeria no mesmo commit.
