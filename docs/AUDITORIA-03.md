# Auditoria 03 — consistência de estados, acessibilidade e temas

**26 de agosto de 2026.** Cobre o app inteiro depois dos prompts 00–19: toda superfície que carrega dados, feedback de escrita, contraste nos dois temas, alvos de toque, copy pt-BR e o recorte 360×640 com escala de texto 1,3.

Nenhuma funcionalidade nova. O que estava consistente ficou. O que divergia — estado vazio de sistema, erro sem `request_id`, botão de ícone sem rótulo, formulário sem `textInputAction`, snackbar ausente — foi unificado.

## Resultado

| Verificação | Depois |
| --- | --- |
| `flutter analyze` | limpo |
| `flutter test` | 372 passando |
| `dart format` | limpo |
| Contraste 4,5:1 dos pares mais usados | teste em `test/core/theme/app_theme_test.dart`, nos dois temas |

---

## Inventário

Para cada superfície: os quatro estados (carregando / vazio / erro / conteúdo), mais offline e “carregar mais” onde cabem. “—” significa que o estado não se aplica (formulário, diálogo, chrome).

### Telas

| Superfície | Carregando | Vazio | Erro | Conteúdo | Offline | Carregar mais |
| --- | --- | --- | --- | --- | --- | --- |
| Splash | spinner (forma imprevisível) | — | `AppErrorState` | redireciona | título “Sem conexão” | — |
| Login / cadastro / reset | botão | — | banner + campos | formulário | botão “Tentar de novo” | — |
| Confirmar reset | botão | — | banner + tela de link inválido | formulário / sucesso | botão “Tentar de novo” | — |
| Lista de veículos | skeleton | sim | `AppErrorState` | lista | sim | — |
| Novo / editar veículo | skeleton (edição) | veículo sumiu = erro | carga + banner | formulário | botão “Tentar de novo” | — |
| Detalhe do veículo | skeleton | 404 como erro | `AppErrorState` | ficha | sim | — |
| Início (home) | skeleton | — (router manda ao cadastro) | `AppErrorState` | dashboard | sim | — |
| Dashboard | skeleton na forma real | implícito (odômetro sempre há) | `AppErrorState` | sim | sim | — |
| Histórico de km | skeleton | sim | `AppErrorState` | lista | sim | spinner + retry, sem apagar o que já está |
| Cuidados | skeleton na forma real | sim | `AppErrorState` | grupos | sim | — |
| Detalhe do plano | skeleton | plano sumiu = erro; histórico próprio | `AppErrorState` | sim | sim | — |
| Lista de manutenções | skeleton | sim | `AppErrorState` | lista | sim | spinner + retry |
| Form de manutenção | botão | — | banner + campos | formulário | botão “Tentar de novo” | — |
| Detalhe da manutenção | skeleton | — | `AppErrorState` | sim | sim | — |
| Timeline | skeleton | sim | `AppErrorState` | lista | sim | spinner + retry |
| Custos | skeleton na forma real | período sem lançamento | `AppErrorState` | sim | sim | — |
| Perfil | skeleton | — | `AppErrorState` | formulário | botão no save | — |
| Excluir conta | botão | — | banner | copy + senha | botão “Tentar de novo” | — |
| Calibrar | skeleton | vai para “pronto” | `AppErrorState` | pergunta / pronto | botão “Tentar de novo” | — |

### Sheets e diálogos

| Superfície | Carregando | Vazio | Erro | Conteúdo | Offline | O que foi alinhado |
| --- | --- | --- | --- | --- | --- | --- |
| Quick add | — | — | — | menu | — | já estava estático |
| Troca de veículo | skeleton | lista + “Adicionar” | `AppErrorState` (mensagem da falha) | lista | sim | deixou de ignorar `ApiFailure.message` |
| Odômetro | botão | — | banner | formulário | botão “Tentar de novo” | `useSafeArea`, `textInputAction` nas notas |
| Rollback de km | — | — | — | diálogo | — | copy já era boa; `correction` não vaza |
| Criar plano | skeleton | catálogo vazio / busca | `AppErrorState` | lista | botão “Tentar de novo” | snackbar de sucesso |
| Ajustar intervalo | botão | — | banner | formulário | botão “Tentar de novo” | `textInputAction`, `useSafeArea`, snackbar |
| Escolher item | skeleton | busca vazia | `AppErrorState` | lista | — | copy da busca |
| Item personalizado | botão | — | banner | formulário | — | `textInputAction`, `useSafeArea` |
| Editar manutenção | botão | — | banner | formulário | botão “Tentar de novo” | `textInputAction`, `useSafeArea` |
| Apagar leitura | — | — | — | diálogo verdadeiro | — | botão em cor de erro; loading na linha |
| Excluir veículo | — | — | — | diálogo verdadeiro | — | snackbar de sucesso |
| Retratar manutenção | — | — | — | diálogo verdadeiro | — | botão com loading |
| Desativar plano | — | — | — | diálogo verdadeiro | — | já dizia o efeito |
| Só histórico | — | — | — | diálogo verdadeiro | — | snackbar de sucesso |
| Sair da conta | — | — | — | diálogo verdadeiro | — | confirmação nova (perfil e onboarding) |
| Descartar form de manutenção | — | — | — | diálogo | — | já existia |

Formulários de escrita não têm os quatro estados de *leitura*: o conteúdo é o form, o erro vai no banner, o carregamento no botão. Splash não tem vazio — é bootstrap.

---

## O que foi corrigido

### 1. Erro e falta de rede passaram a ser uma decisão só

`AppErrorState` agora tem `fromError`. Sem conexão ganha título **Sem conexão**, ícone de wifi e a frase que o produto é online por decisão:

> O Meu Auto precisa de internet para funcionar. Conecte-se e tente de novo.

Timeout: “O servidor demorou a responder. Tente de novo.” Código `internal`: a mensagem do servidor e a referência (`request_id`) em letra miúda. O botão é sempre “Tentar de novo”.

Os `_messageOf` copiados em cerca de dez telas saíram. Listas paginadas continuam mostrando o rodapé de “carregar mais” sem apagar o que já está na tela.

### 2. Vazio do lado de quem usa o carro

| Antes | Depois |
| --- | --- |
| Nenhuma leitura ainda | A quilometragem do seu carro começa aqui |
| Nenhum plano ainda | Os cuidados do seu carro começam aqui |
| Nenhuma manutenção registrada ainda | O histórico de serviços do seu carro começa aqui |
| Nenhum registro deste item ainda | Ainda não há serviço deste item. O primeiro registro começa o histórico. |
| Nada foi registrado nos últimos N meses | Nenhum custo nos últimos N meses. Troque o intervalo ou registre um serviço. |
| Nenhum item com esse nome | Nada com esse nome. Tente outra busca. |

A lista de veículos ganhou uma frase sob o título. A timeline já estava certa (“O histórico do seu carro começa aqui”) e ficou.

### 3. Feedback de ação

- Botões de rede: loading e desabilitados enquanto enviam — inclusive apagar leitura e retratar, que confirmavam e disparavam no silêncio.
- Sucesso de escrita: snackbar curto em cadastro/edição de veículo, exclusão, nome, plano, intervalo, “só histórico”, manutenção, quilometragem. **Desfazer** no save do nome.
- Destrutivas: o diálogo já dizia o efeito; apagar leitura passou a usar a cor de erro; **Sair** agora confirma (“Você sai neste aparelho. Para voltar, use e-mail e senha”).
- Nenhum diálogo bloqueante para operação normal.

### 4. Acessibilidade

- Contraste 4,5:1 medido nos pares que as telas pintam (texto, campo, erro, snackbar, navegação, chips de status) nos dois temas. Os pares já passavam; o teste é que impede regressão.
- Alvo de toque 48 dp já vinha do tema.
- `AppIconButton` (e `Semantics` no título do carro, na FAB, na navegação e no olho da senha): botão de ícone sem rótulo visível agora tem label falado.
- Chip de status: ícone **e** texto. O rótulo `sem_periodicidade` passou de “Sem periodicidade” para **Só histórico**.
- `textInputAction` encadeado nos formulários que faltavam (intervalo, manutenção, edição, calibrar, notas do odômetro, item personalizado).
- Escala 1,3 em 360×640: `test/ux/small_screen_test.dart` passou a incluir dashboard, vazios das listas principais e os dois estados de erro.

### 5. Temas e tamanhos

Preferência do Prompt 19 (`themeModeProvider` + `SharedPreferences`) não foi relitigada: continua persistindo claro / escuro / sistema, com teste em `test/core/theme/theme_mode_store_test.dart`.

`AppScaffold` já limitava a largura a 640. Sheets de formulário passaram a `useSafeArea: true` e continuam empurrando o teclado com `viewInsets`. Skeleton já respeitava `MediaQuery.disableAnimations`.

### 6. Texto

Nenhuma string visível com “baseline”, “correction”, “payload” ou “cursor”. Sem exclamação, sem emoji. Botão de retry diz o que vai acontecer. Chip e frases de status não discordam mais no tom.

---

## Cobertura acrescentada

- `test/shared/widgets/app_error_state_test.dart` — offline com título próprio; `internal` com referência.
- `test/shared/widgets/app_status_chip_test.dart` — cada status tem ícone e texto.
- `test/ux/empty_copy_test.dart` — copy dos vazios principais, do lado do dono.
- Estados do dashboard (`DashboardView`): skeleton, erro offline, conteúdo.
- Contraste dos pares de cor mais usados e de todos os chips, nos dois temas.
- `small_screen_test` ampliado.

---

## Manual

Percorrer o app nos dois temas, escala de texto 1,3, janela 360×640. Desligar a rede no emulador e repetir: cada tela de leitura deve cair em **Sem conexão** com “Tentar de novo”; cada formulário deve relabelar o botão.

Isso não rodou neste passo — não havia emulador nesta sessão. O que a suíte cobre: os quatro estados do dashboard, os vazios principais, os dois erros (offline e interno) em 360×640 nos dois temas, e o contraste medido. O passe com rede desligada no aparelho continua sendo o critério de aceite que só o dono do emulador fecha.

---

## Deliberadamente não inventado

- Ilustração de estado vazio.
- Biblioteca de animação.
- Undo de exclusão (o diálogo já diz que não dá para desfazer).
- Tela de “sem permissão” (404 continua 404).
- Recálculo de vencimento no app.
