# Identidade visual

Definida, gerada e processada em 27/08/2026. A arte existe. Este arquivo registra o que foi decidido — não é um briefing para arte futura.

Nada disto é cor nova. Tudo sai da metade da paleta que o app já tinha em `AppColors`.

## Conceito

Um mostrador de instrumento visto à noite, cujo ponteiro se resolve num check.

Painel de instrumentos é a linguagem visual inequivocamente automotiva. Um símbolo claro sobre campo teal lia como confirmação de compra; o fundo escuro é o que faz o mostrador parecer cluster, não selo de checkout.

## Paleta

| Uso | Hex | Token |
| --- | --- | --- |
| Fundo do ícone e da splash escura | `#121717` | `AppColors.dark.surface` |
| Graduações e ponteiro (ícone, splash escura, camada adaptativa) | `#7ED4CE` | `AppColors.dark.primary` |
| Ponta do ponteiro | `#F0B27A` | `AppColors.dark.tertiary` |
| Símbolo da splash clara | `#0F6E6A` | `AppColors.light.primary` |
| Fundo da splash clara | `#F4F6F6` | `AppColors.light.surface` |

O teal claro `#7ED4CE` sobre `#F4F6F6` fica praticamente invisível. Por isso existem dois arquivos de splash, e não se troca um pelo outro.

## Os quatro assets

Todos em `assets/icon/`. 1024×1024. Não redimensionar, não recortar, não recentralizar, não recolorir, não “otimizar” o alfa (`-fuzz`, threshold, remoção de fundo). O alfa foi desmultiplicado contra o fundo conhecido; reprocessar devolve franja cinza nas bordas.

| Arquivo | Uso | O que não pode mudar |
| --- | --- | --- |
| `icon.png` | iOS e Android legado | RGB opaco, fundo `#121717`. A App Store rejeita canal alfa; `remove_alpha_ios: true` no gerador é a rede de segurança. |
| `icon_foreground.png` | Camada adaptativa do Android, e splash do Android 12+ | RGBA. A marca ocupa **58,2%** do lado. A zona segura do ícone adaptativo é **61%**; a arte original ocupava 77,5% e as graduações externas seriam cortadas pela máscara circular. Já conferida contra círculo, squircle e quadrado arredondado. |
| `splash_light.png` | Símbolo da splash no tema claro | RGBA, teal `#0F6E6A`. Só no claro. |
| `splash_dark.png` | Símbolo da splash no tema escuro | RGBA, teal `#7ED4CE`. Só no escuro. |

A camada adaptativa foi derivada da imagem colorida, não de uma versão branca, para Android e iOS mostrarem a mesma marca. Um símbolo branco produziria duas identidades.

### Medidas travadas

- **58,2%** — ocupação da marca em `icon_foreground.png`.
- **61%** — zona segura do ícone adaptativo do Android. Abaixo disso a máscara (círculo, squircle ou quadrado arredondado) não corta as graduações.
- **66,7%** — o que a splash do Android 12+ mostra, recortada num círculo. `splash_dark.png` ocupa ~70% e seria cortado; por isso o bloco `android_12` aponta para `icon_foreground.png`, que já respeita o 58,2%. Não “corrigir” para `splash_dark.png`.

No Android 12+ o mesmo `icon_foreground.png` (teal claro) vai nos dois temas. No claro o contraste é menor do que o da splash pré-12; o recorte circular pesou mais do que ter um segundo arquivo.

## Como regenerar

Os recursos em `android/app/src/main/res/` e `ios/Runner/Assets.xcassets/` são gerados e commitados. O build não os recria. Depois de qualquer mudança no `pubspec.yaml` dos geradores:

```bash
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Dois detalhes do `pubspec.yaml` que não estão no template óbvio dos pacotes:

- `adaptive_icon_foreground_inset: 0` — o default do `flutter_launcher_icons` é 16. A PNG já tem a margem de 58,2%; outro inset encolheria a marca.
- `web: false` no `flutter_native_splash` — este app não tem alvo web; sem isso o gerador cria uma pasta `web/`.

Depois do `flutter_launcher_icons`, conferir `ios/Runner.xcodeproj/project.pbxproj`. A v0.14.4 procura qualquer linha com `ASSETCATALOG` e escreve `= AppIcon`, o que corrompe `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` (precisa continuar `YES`). `ASSETCATALOG_COMPILER_APPICON_NAME` já era `AppIcon`; se só isso mudou, reverter o pbxproj.

Revisar o diff antes de commitar: alteração fora de recurso de ícone ou de splash significa que algo saiu do lugar. Os quatro PNGs em `assets/icon/` não podem aparecer no diff.

## Splash nativa e SplashScreen interna

São duas telas, em momentos distintos do boot, e não se unificam.

1. **Splash nativa** — símbolo sobre a cor do tema, antes de o Flutter subir. Não pode depender do Dart.
2. **`SplashScreen`** (`lib/features/auth/presentation/splash_screen.dart`, rota `/splash`) — wordmark (“Meu” neutro + “Auto” teal) enquanto a sessão resolve.

Os fundos são os mesmos dos dois lados (`AppColors.light.surface` / `AppColors.dark.surface`), para a troca parecer uma tela só ganhando conteúdo. A splash nativa segue o tema do sistema; se o app estiver forçado no outro modo, a emenda não casa — isso é o tema persistido, não a arte.

A correção menor, se a transição incomodar no aparelho, é pôr o símbolo acima do wordmark na `SplashScreen`, escolhendo `splash_light.png` ou `splash_dark.png` conforme o brilho do tema. Só isso, e só se incomodar de verdade.

## Ponto aberto

A **29 px** (menor tamanho do iOS, Ajustes e Spotlight) as graduações se dissolvem e sobra o check. Continua identificável e não bloqueia publicar. Se um dia incomodar, o caminho é vetorizar a marca e fazer uma variante com menos graduações e mais grossas — não é reprocessar o PNG atual.
