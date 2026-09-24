# Design system

Definido em 24/09/2026 no redesign completo do app. Este arquivo é a referência
do que existe e de como usar; a identidade dos assets nativos (ícone, splash)
continua em `IDENTIDADE-VISUAL.md`.

## A ideia

Um painel de instrumentos visto à noite. Fundo azul-marinho profundo com uma
luz suave no canto superior direito, superfícies um degrau acima do fundo com
um fio de borda, um único acento elétrico para o que está selecionado, é link,
ou está em dia. Vermelho só para o que está realmente atrasado; âmbar para o
que está perto. Nada é fotografia; nada é textura.

O modo escuro é a identidade. O claro é a mesma identidade à luz do dia e
continua disponível em Perfil > Aparência.

## Tokens (`lib/core/theme`)

| Arquivo | O que guarda |
| --- | --- |
| `app_colors.dart` | `AppColors.dark` e `AppColors.light` — os dois `ColorScheme`. `electric` (`#22B8FF`) é o acento do escuro; `electricDeep` (`#0A66C2`) o do claro. |
| `app_tones.dart` | `AppTones`, um `ThemeExtension` com o que o scheme não nomeia: degradê da página (`pageTop`/`pageBottom`), `glow`, `stroke`/`strokeStrong` (fios de borda), `highlight`, `iconWell`, `track`, `accentSoft`, `divider`, `overlayPressed`. Leia com `AppTones.of(context)`. |
| `app_typography.dart` | Inter para texto (`kAppFontFamily`), Rajdhani para figuras de instrumento (`AppTypography.instrument`). Todos os estilos têm figuras tabulares. |
| `app_status_colors.dart` | `AppStatus` + `statusColors`: o único lugar que mapeia estado de domínio para cor, ícone e rótulo. `isLoud` diz quais estados podem pintar uma linha. |
| `app_spacing.dart` | Escala de 4dp, `page` (20) como calha lateral, `block` (28) entre blocos, `screen`/`screenHeaded` como padding de tela. |
| `app_radius.dart` | `xs` 4 (barras), `s` 10 (chips), `m` 16 (cards, grupos, campos), `l` 22 (folhas, diálogos). |
| `app_motion.dart` | Durações, curvas e `pressScale`. `AppMotion.of` zera com "reduzir movimento". |
| `app_theme.dart` | O `ThemeData`. Tudo que o Material desenha sozinho (date picker, switch, diálogo) é configurado aqui. |

Regra: nenhuma cor, raio ou espaçamento literal fora desta pasta. Um valor que
não existe nos tokens é uma decisão nova e entra aqui primeiro.

### Contraste

`test/core/theme/app_theme_test.dart` verifica 4,5:1 em todos os pares que as
telas pintam, nos dois temas, e em todos os chips de status. Mudar uma cor sem
rodar esse teste é como mudar sem saber.

## Componentes (`lib/shared/widgets`)

### Estrutura

- `AppBackground` — o degradê e a luz. Só `AppScaffold` o desenha.
- `AppScaffold` — moldura de toda tela: fundo, app bar transparente, corpo
  com largura máxima, pull-to-refresh.
- `AppShell` (`core/router`) — a barra de quatro abas, com fio no topo.
- `AppSurface` — o contêiner. `none` (sem preenchimento), `grouped` (um degrau
  acima, fio), `raised` (dois degraus, fio forte, luz na borda superior: para
  o que é ação).
- `AppGroup` — rótulo quieto fora, linhas dentro de uma `AppSurface.grouped`
  com fios entre elas. É a lista agrupada de qualquer app de configurações.
- `AppSectionHeader` — `label` (quieto, para grupos) ou `title` (para uma
  seção que é o assunto da tela, como "Próximos cuidados"). A ação à direita é
  `AppSectionAction`: link no acento com chevron.

### Linhas

- `AppIconWell` — ícone num círculo com fio. Tamanhos `s`/`m`/`l`/`xl`; tons
  `neutral`, `accent`, `status`. É o único jeito de um ícone aparecer ao lado
  de um nome.
- `AppListRow` — poço, nome, uma linha de estado, chevron ou `trailing`.
  `status` tinge poço e texto só para `vencido`/`vence_em_breve`.
- `AppListRowShell` — o alvo de toque e o ritmo de uma linha, com interior
  próprio.
- `AppSettingRow`, `AppFactRow` (empilhada ou `inline`), `AppChoiceRow`
  (escolha única), `AppSwitchRow` (sim/não), `AppTimelineTile` (nó no trilho).

### Ações

- `AppButton` — `primary` (acento preenchido), `secondary` (contorno sobre
  superfície), `destructive` (vermelho tonal), `tertiary` (texto). `expanded`
  estica; `compact` para dentro de uma linha; `icon` e `loading`.
- `AppQuickAction` — tile elevado com poço, rótulo e chevron. Dois lado a lado
  têm exatamente o mesmo peso.
- `AppPressable` — encolhe 2,5% sob o dedo. Respeita reduzir movimento.
- `AppIconButton` — ícone só, com rótulo falado.

### Estado e figuras

- `AppStatusChip` — pílula com glifo, palavra e tom.
- `AppProgressBar` — barra fina, só quando o chamador tem uma fração real
  (`planProgress` em `features/maintenance/domain/plan_progress.dart`).
- `AppMetric` — número em Rajdhani com unidade e rótulo.
- `AppPlateChip` — a placa, desenhada como placa.
- `AppDetailHeader` — cabeça de tela de detalhe: poço grande, título, chip e
  frase de estado.
- `AppWordmark` — "Meu Auto" como marca tipográfica, três tamanhos.

### Formulários e folhas

- `AppFormSection` / `AppFormGap` / `AppFormFooter` — seções nomeadas com
  espaçamento fixo e o botão principal fixado embaixo.
- `AppFoldedSection` — grupo de campos que começa fechado; abre sozinho quando
  um erro do servidor cai num campo dentro dele.
- `AppMoneyField`, `AppKmField`, `AppLitersField`, `AppDateField` — campos
  com máscara; nunca um número cru.
- `showAppSheet` + `AppSheetBody` (folha que cabe no conteúdo) ou
  `AppSheetFrame` (folha alta com lista). `isForm: true` tira o arrasto e o
  fechamento passa por `AppSheetHeader`, que pergunta antes de descartar.
- `AuthFormBanner` — a faixa de erro do formulário inteiro.
- `confirmAction` — o diálogo de confirmação; o botão diz o verbo.

### Estados

- `AppEmptyState`, `AppErrorState` — poço grande, título, frase, uma ação.
  Rolam sempre, para o pull-to-refresh funcionar.
- `AppSkeleton` / `AppSkeletonList` — a forma do que vai chegar, respirando.
- `showAppSnackBar` / `showAppErrorSnackBar` — confirmação (com "Desfazer"
  que some sozinho) e falha, em cores diferentes.

## Iconografia

Material Icons, sempre a variante `_outlined`. `maintenance_icons.dart` mapeia
slug do catálogo para glifo; `alertIconOf` faz o mesmo para avisos.

## Tipografia

Inter (400/500/600/700) e Rajdhani (600/700), em `assets/fonts/`, sob a SIL
Open Font License (os textos da licença estão ao lado). Rajdhani só aparece em
`AppTypography.instrument`: odômetro, totais, quilometragem numa ficha. Nunca
em texto corrido.

## Galeria

`test/support/design_gallery.dart` renderiza todos os tokens e componentes numa
página, e `test/widget_test.dart` a bombeia nos dois temas. Componente novo
entra na galeria no mesmo commit.

## Fora do escopo desta versão

- O ícone e a splash foram re-tingidos do teal para o azul elétrico com
  `tool/recolor_icons.dart`; o desenho é o mesmo. Um redesenho do símbolo é
  trabalho de arte, não de código.
