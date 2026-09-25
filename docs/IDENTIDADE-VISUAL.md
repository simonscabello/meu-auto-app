# Identidade visual

Definida, gerada e processada em 27/08/2026; re-tingida em 24/09/2026 quando o
app trocou o teal pelo azul elétrico, e de novo em 25/09/2026 quando o segundo
redesign trocou o navy com brilho pelo grafite e o azul de sinal. A arte
existe. Este arquivo registra o que foi decidido — não é um briefing para arte
futura. O design system das telas está em `DESIGN-SYSTEM.md`.

Nada disto é cor nova. Tudo sai da paleta que o app tem em `AppColors`.

## Conceito

Um mostrador de instrumento, cujo ponteiro se resolve num check.

Painel de instrumentos é a linguagem visual inequivocamente automotiva. O fundo
escuro é o que faz o mostrador parecer cluster, não selo de checkout. Desde o
grafite ele é o mesmo quase-preto da página do app, sem azul no fundo: o azul
fica só no que está aceso, como nas telas.

## Paleta

| Uso | Hex | Token |
| --- | --- | --- |
| Fundo do ícone e da splash escura | `#090C10` | `AppColors.dark.surface` |
| Graduações acesas e ponteiro (ícone, splash escura, camada adaptativa) | `#5B9DFF` | `AppColors.signal` |
| Graduações apagadas (ícone, camada adaptativa) | `#3A4350` | `AppTones.dark.strokeStrong` |
| Ponta do ponteiro | `#EFB54A` | `AppColors.dark.tertiary` |
| Símbolo da splash clara | `#1A66DA` | `AppColors.signalDeep` |
| Ponta do ponteiro na splash clara | `#93580A` | `AppColors.light.tertiary` |
| Fundo da splash clara | `#F2F4F7` | `AppColors.light.surface` |

As graduações apagadas deixaram de ser `outline`. No grafite o `outline`
(`#6C7888`) é a borda de 3:1 dos campos, e com ele o arco apagado ficava quase
tão claro quanto o aceso — o mostrador perdia o "aceso até aqui". Com
`strokeStrong` o aceso fica cerca de seis vezes mais luminoso que o apagado,
perto dos quatro que a arte original tinha. As duas versões foram geradas e
comparadas antes da escolha (`TICK` no `tool/recolor_icons.dart`).

O azul de sinal `#5B9DFF` sobre `#F2F4F7` não passa de 3:1. Por isso existem
dois arquivos de splash, e não se troca um pelo outro.

## Os quatro assets

Todos em `assets/icon/`. 1024×1024. Não redimensionar, não recortar, não
recentralizar, não "otimizar" o alfa (`-fuzz`, threshold, remoção de fundo). O
alfa foi desmultiplicado contra o fundo conhecido; reprocessar devolve franja
cinza nas bordas.

As re-tintagens de 24 e 25/09/2026 foram feitas por `tool/recolor_icons.dart`,
que mapeia cada pixel como a mesma mistura das âncoras novas que ele era das
antigas e preserva o alfa byte a byte. Rodar com
`flutter test tool/recolor_icons.dart --dart-define=APPLY=true`; sem `APPLY`
ele só imprime a paleta, e com `--dart-define=OUT=<pasta>` grava o resultado
lá em vez de em `assets/icon/`, para olhar antes de decidir. Uma nova mudança
de paleta passa por ele, não por um editor: a coluna "antiga" do mapeamento é
sempre o que os arquivos têm hoje.

| Arquivo | Uso | O que não pode mudar |
| --- | --- | --- |
| `icon.png` | iOS e Android legado | RGB opaco, fundo `#090C10`. A App Store rejeita canal alfa; `remove_alpha_ios: true` no gerador é a rede de segurança. |
| `icon_foreground.png` | Camada adaptativa do Android, e splash do Android 12+ | RGBA. A marca ocupa **58,2%** do lado. A zona segura do ícone adaptativo é **61%**; a arte original ocupava 77,5% e as graduações externas seriam cortadas pela máscara circular. |
| `splash_light.png` | Símbolo da splash no tema claro | RGBA, azul `#1A66DA`. Só no claro. |
| `splash_dark.png` | Símbolo da splash no tema escuro | RGBA, azul `#5B9DFF`. Só no escuro. |

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

## Pontos abertos

`icon_foreground.png` tem um halo preto em volta das marcas — era o brilho da
arte original, e some sobre o fundo escuro do ícone adaptativo. Mas o bloco
`android_12` usa esse mesmo arquivo na splash clara (`#F2F4F7`), onde o halo
aparece como sombra suja. Já era assim antes do grafite. Resolver pede um
quinto arquivo — a camada adaptativa sem halo, só para a splash clara do
Android 12+ — e não uma edição deste.

A **29 px** as graduações se dissolvem e sobra o check. Continua identificável
e não bloqueia publicar. Se um dia incomodar, o caminho é vetorizar a marca e
fazer uma variante com menos graduações e mais grossas.
