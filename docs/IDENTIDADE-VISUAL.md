# Identidade visual

Definida, gerada e processada em 27/08/2026; re-tingida em 24/09/2026 quando o
app trocou o teal pelo azul elétrico. A arte existe. Este arquivo registra o
que foi decidido — não é um briefing para arte futura. O design system das
telas está em `DESIGN-SYSTEM.md`.

Nada disto é cor nova. Tudo sai da paleta que o app tem em `AppColors`.

## Conceito

Um mostrador de instrumento visto à noite, cujo ponteiro se resolve num check.

Painel de instrumentos é a linguagem visual inequivocamente automotiva. O fundo
escuro é o que faz o mostrador parecer cluster, não selo de checkout.

## Paleta

| Uso | Hex | Token |
| --- | --- | --- |
| Fundo do ícone e da splash escura | `#060E18` | `AppColors.dark.surface` |
| Graduações acesas e ponteiro (ícone, splash escura, camada adaptativa) | `#22B8FF` | `AppColors.dark.primary` |
| Graduações apagadas (ícone, camada adaptativa) | `#3D5A7A` | `AppColors.dark.outline` |
| Ponta do ponteiro | `#FFC857` | `AppColors.dark.tertiary` |
| Símbolo da splash clara | `#0A66C2` | `AppColors.light.primary` |
| Ponta do ponteiro na splash clara | `#8A5A00` | `AppColors.light.tertiary` |
| Fundo da splash clara | `#EEF3F8` | `AppColors.light.surface` |

O azul elétrico `#22B8FF` sobre `#EEF3F8` não passa de 2:1. Por isso existem
dois arquivos de splash, e não se troca um pelo outro.

## Os quatro assets

Todos em `assets/icon/`. 1024×1024. Não redimensionar, não recortar, não
recentralizar, não "otimizar" o alfa (`-fuzz`, threshold, remoção de fundo). O
alfa foi desmultiplicado contra o fundo conhecido; reprocessar devolve franja
cinza nas bordas.

A re-tintagem de 24/09/2026 foi feita por `tool/recolor_icons.dart`, que mapeia
cada pixel como a mesma mistura das âncoras novas que ele era das antigas e
preserva o alfa byte a byte. Rodar com
`flutter test tool/recolor_icons.dart --dart-define=APPLY=true`; sem `APPLY`
ele só imprime a paleta. Uma nova mudança de paleta passa por ele, não por um
editor.

| Arquivo | Uso | O que não pode mudar |
| --- | --- | --- |
| `icon.png` | iOS e Android legado | RGB opaco, fundo `#060E18`. A App Store rejeita canal alfa; `remove_alpha_ios: true` no gerador é a rede de segurança. |
| `icon_foreground.png` | Camada adaptativa do Android, e splash do Android 12+ | RGBA. A marca ocupa **58,2%** do lado. A zona segura do ícone adaptativo é **61%**; a arte original ocupava 77,5% e as graduações externas seriam cortadas pela máscara circular. |
| `splash_light.png` | Símbolo da splash no tema claro | RGBA, azul `#0A66C2`. Só no claro. |
| `splash_dark.png` | Símbolo da splash no tema escuro | RGBA, azul `#22B8FF`. Só no escuro. |

### Medidas travadas

- **58,2%** — ocupação da marca em `icon_foreground.png`.
- **61%** — zona segura do ícone adaptativo do Android.
- **66,7%** — o que a splash do Android 12+ mostra, recortada num círculo.
  `splash_dark.png` ocupa ~70% e seria cortado; por isso o bloco `android_12`
  aponta para `icon_foreground.png`. Não "corrigir" para `splash_dark.png`.

## Como regenerar

Os recursos em `android/app/src/main/res/` e `ios/Runner/Assets.xcassets/` são
gerados e commitados. Depois de qualquer mudança nos PNGs ou no `pubspec.yaml`
dos geradores:

```bash
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Dois detalhes do `pubspec.yaml` que não estão no template óbvio dos pacotes:

- `adaptive_icon_foreground_inset: 0` — a PNG já tem a margem de 58,2%.
- `web: false` no `flutter_native_splash` — este app não tem alvo web.

Depois do `flutter_launcher_icons`, conferir `ios/Runner.xcodeproj/project.pbxproj`:
`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` precisa continuar
`YES`.

## Splash nativa e SplashScreen interna

São duas telas, em momentos distintos do boot, e não se unificam.

1. **Splash nativa** — símbolo sobre a cor do tema, antes de o Flutter subir.
2. **`SplashScreen`** (`lib/features/auth/presentation/splash_screen.dart`) —
   wordmark sobre o mesmo fundo enquanto a sessão resolve.

O app abre no tema escuro por padrão (`ThemeModeStore`); a splash nativa segue
o tema do sistema. Num aparelho em modo claro a emenda mostra a splash clara e
depois o app escuro — é o tema persistido, não a arte.

## Ponto aberto

A **29 px** as graduações se dissolvem e sobra o check. Continua identificável
e não bloqueia publicar. Se um dia incomodar, o caminho é vetorizar a marca e
fazer uma variante com menos graduações e mais grossas.
