# Auditoria 01 — a fundação

**26 de agosto de 2026.** Cobre os prompts 00 a 07: configuração, design system, núcleo de domínio, camada HTTP, sessão e autenticação. Momento escolhido de propósito — existe uma tela provisória e nenhuma tela de produto, então cada erro corrigido aqui é um erro que não vira padrão copiado nas quinze etapas seguintes.

## Resultado

| Verificação | Antes | Depois |
| --- | --- | --- |
| `flutter analyze` | limpo | limpo |
| `flutter test` | 78 passando | 100 passando |
| `dart format` | 2 arquivos fora | limpo |
| `flutter pub outdated` | 2 majors disponíveis | adiados, com decisão registrada |

Quatro correções, três delas em código. Nenhuma funcionalidade nova.

---

## O que foi corrigido

### 1. Uma queda de sinal apagava a sessão do usuário — grave

**Onde:** `lib/core/session/session_manager.dart`, em `_refreshOnce`.

O tratamento de falha era `on Object { await _endSession(); return false; }` — ou seja, **qualquer** exceção limpava o armazenamento e derrubava a sessão. Isso inclui `connectionError` e timeout, que são exatamente o que acontece sem sinal.

O caminho completo do bug:

1. O dono abre o app na garagem do estacionamento, sem sinal, mais de 15 minutos depois do último uso.
2. `validAccessToken()` vê o access token vencendo e chama `refresh()`.
3. O Dio estoura `connectionError`. A requisição **nunca chegou ao servidor**.
4. `_endSession()` apagava os tokens e emitia sessão encerrada.
5. O `AuthController` mandava para o login — onde o usuário não consegue entrar, porque continua sem rede, e agora precisa de uma senha que pode não ter na cabeça.

O refresh token estava válido por trinta dias e foi jogado fora sem que o servidor tivesse opinado sobre ele.

Isso importa mais neste produto do que na média: o `PRODUCT.md` descreve o usuário como alguém "de pé, no meio de um corre" — no posto, no balcão da oficina, na garagem — e registra a ausência de operação offline como risco real justamente por isso.

**A correção** separa duas coisas que não são a mesma:

- **O servidor respondeu e recusou** (4xx) → o token está morto → encerra a sessão. Continua igual.
- **Não veio resposta** (queda de conexão, timeout, 5xx) → o token nunca foi gasto → **preserva**, devolve `false`, não emite sessão encerrada.
- **O servidor respondeu 2xx mas a resposta não pôde ser lida** → caso sutil, e aqui encerrar é o certo: o servidor **já rotacionou** o token que enviamos, então o que está em disco está revogado. Apresentá-lo de novo seria lido como reúso e derrubaria todas as sessões do usuário — exatamente o que a arquitetura de refresh existe para evitar.

Aproveitando a mesma leitura, `validAccessToken()` ficou menos frágil: quando a renovação proativa falha mas o token em disco **ainda não venceu de fato**, ele é enviado assim mesmo. A janela de 60 segundos é margem de segurança, não prazo — e um token que ainda funciona vale mais que nenhum.

**Coberto por** `test/core/session/session_offline_refresh_test.dart`, seis casos. Os cinco testes de sessão que já existiam, inclusive o de concorrência, continuam passando sem alteração.

### 2. Faltava localização pt-BR

**Onde:** `lib/main.dart` e `pubspec.yaml`.

O `MaterialApp.router` não declarava `locale`, `supportedLocales` nem `localizationsDelegates`. A formatação de datas e moeda já estava certa, via `intl` — mas todo widget do Material que o app **não** escreve renderiza com as strings padrão, que são em inglês.

Na prática isso vale para os seletores de data, os botões de diálogo e o menu de seleção de texto. Os prompts 11, 14, 16 e 17 abrem seletor de data em quase toda tela de formulário, e todos abririam em inglês, com ordem de data americana — violando a regra de que toda string visível é pt-BR, em quatorze telas de uma vez.

`flutter_localizations` foi adicionado (vem do SDK, não é dependência de terceiro) e o locale foi fixado em `pt_BR`, que é o único em escopo.

**Efeito colateral que vale saber:** `flutter_localizations` **fixa a versão do `intl`** em 0.20.2. A restrição do projeto era `^0.20.3` e o `pub get` passou a falhar. Agora está `^0.20.2`, com comentário no `pubspec.yaml`. Subir o `intl` sem checar isso volta a quebrar a resolução.

### 3. O logger de debug podia derrubar uma requisição

**Onde:** `lib/core/network/logging_interceptor.dart`.

`_logRequest` roda em `onRequest`, antes de `handler.next`, e chama `jsonEncode` no corpo. Um corpo que o `jsonEncode` não consiga serializar faria a requisição falhar — **só em debug**, que é a pior categoria de bug: aparece durante o desenvolvimento, some no build de release, e quem procura vai olhar para o servidor.

As três chamadas de log passaram a ser envolvidas por `_safely`, que engole qualquer erro de formatação e escreve `[log falhou]`. Perder uma linha de log não é nada; perder a requisição é um bug.

### 4. `CLAUDE.md` afirmava que o repositório estava vazio

A seção "State of the repo" ainda dizia **"Empty. No Flutter project has been scaffolded yet."** O Cursor carrega esse arquivo em toda conversa, e ele estava informando o oposto da realidade nos catorze prompts que ainda faltam — com risco real de alguém re-scaffoldar por cima ou reabrir decisões já tomadas.

Foi reescrita para registrar o que existe: a estrutura, as decisões de arquitetura que **não** devem ser relitigadas no meio de uma feature, a armadilha do refresh rotativo com os dois testes que a guardam, e o aviso de que os seis widgets ainda sem uso são propositais.

---

## O que foi verificado e estava certo

Vale registrar, porque saber o que **não** precisa ser reexaminado é metade do valor de um checkpoint.

**Fronteiras.** Nada em `lib/core/domain` importa Flutter — e existe um teste que falha se alguém importar. Nada em `lib/shared` importa `lib/features`. `lib/core/router` importa telas de `features`, o que é esperado: um router precisa conhecer os destinos.

**Unicidade.** Existe exatamente um `ApiClient`, um `ApiFailure`, um `TokenStorage`, um `SessionManager`. Nenhuma URL fora de `AppConfig`. Nenhum path de API fora de `api_paths.dart`. Nenhuma abstração com implementação única e sem motivo — `TokenStorageBackend` tem duas de verdade (seguro e memória) e existe para os testes poderem contar leituras.

**Concorrência do refresh.** Reli `refresh()` procurando qualquer ponto de escape. Não há: entre a checagem de `_inFlightRefresh` e a atribuição não existe `await`, então nada pode se intercalar. O `AuthInterceptor` ainda melhora isso — antes de pedir renovação, compara o token que a requisição enviou com o que está em disco, e se alguém já renovou, apenas repete com o novo, sem uma segunda chamada.

**Erros.** Nenhum `DioException` escapa de `lib/core/network` — o `ApiClient` desembrulha tudo para `ApiFailure`. Nenhum `catch` vazio, nenhum `print`, nenhum erro engolido em silêncio. O único enum de fio existente, `ApiErrorCode`, tem `desconhecido` e passa pelo `parseEnum`.

**Segurança.** `grep` por token, senha e `Authorization` em todo o `lib/`: nada é logado. O header é redigido, e `password`, `access_token`, `refresh_token` e `token` são redigidos em qualquer corpo, em qualquer profundidade. `SessionTokens.toString()` e `Session.toString()` omitem os valores — e há teste para os dois. Nada sensível vai para `shared_preferences`; `TokenStorage` é o único ponto que fala com o armazenamento seguro.

**Contrato.** As telas de autenticação não inventam regra: a dica do campo de senha diz "mínimo de 8 caracteres, sem exigência de símbolo ou número", que é exatamente a regra do backend. O 422 marca campo por campo a partir de `details.fields`. O 429 tem mensagem própria. O 401 do login mostra a mensagem do servidor sem dizer qual campo errou — como o contrato pede, já que a resposta é idêntica para senha errada e e-mail inexistente.

**Estados e layout.** O splash trata `AsyncError` com mensagem e botão de tentar de novo, e o `authStatusOf` devolve `AuthUnknown` nesse caso, o que mantém o usuário no splash em vez de empurrá-lo para uma tela quebrada. Login e cadastro têm banner, erro por campo, botão em carregamento, campos desabilitados durante o envio e rótulo que vira "Tentar de novo" quando a falha é de rede.

Foi acrescentado `test/ux/small_screen_test.dart`, que renderiza as quatro telas em 360x640, nos dois temas, com escala de texto 1.0 e 1.3 — dezesseis combinações — e falha se qualquer uma estourar o layout. Nenhuma estourou. É o tipo de verificação que ninguém repete à mão a cada prompt, então virou teste.

---

## Código morto: o que foi mantido, e por quê

Seis dos nove widgets do design system não têm uso hoje: `AppCard`, `AppEmptyState`, `AppMetric`, `AppSectionHeader`, `AppSkeleton` e `AppStatusChip`. O mesmo vale para a maior parte das entradas de `ApiPaths`.

**Mantidos deliberadamente.** Todos são nomeados explicitamente pelos prompts 09 a 18 — `AppMetric` é o widget da quilometragem no dashboard, `AppStatusChip` aparece em três telas de prazo, `AppSkeleton` em todo estado de carregamento. Apagar agora para recriar em duas semanas é churn, não limpeza. Ficou registrado no `CLAUDE.md` para ninguém os remover como código morto numa próxima varredura.

**Removido:** `cupertino_icons`, que veio do `flutter create` e nunca foi referenciado. O `CLAUDE.md` é explícito de que o app usa uma linguagem visual Material só, nos dois sistemas, então nada iria usá-lo. As dependências diretas agora são exatamente as oito previstas.

---

## Adiado, com decisão explícita

`flutter_riverpod` 2.6.1 → 3.4.2 e `go_router` 17.5.0 → 18.0.0 estão disponíveis e são majors com quebra de API.

**Decisão: ficar onde estamos até o MVP fechar.** O argumento a favor de subir agora é real — existem 4 providers hoje e serão umas 40 no Prompt 22, então este é o momento mais barato. O argumento contra é mais forte: trocar a API da biblioteca de estado no meio de catorze prompts de feature troca um custo conhecido e pequeno por um risco desconhecido, e faria o agente lutar contra a API nova em cada tela. Reabrir como tarefa dedicada depois do Prompt 22.

Registrado em `docs/DECISOES-EM-ABERTO.md` junto com a divergência do client gerado, para que nenhuma das três vire dívida esquecida.

---

## Próximo passo

Prompt 09 — veículos e shell de navegação. A fundação está pronta para receber telas de produto.

Uma verificação manual continua valendo antes de seguir, porque nenhum teste automatizado cobre: subir a API conforme `docs/RODANDO.md`, cadastrar um usuário no emulador, fechar e reabrir o app, e **desligar a rede do emulador e reabrir** — a sessão precisa sobreviver, que é a correção número 1 acontecendo na prática.
