# Auditoria 02 — a primeira fatia vertical

**26 de agosto de 2026.** Cobre os prompts 09 a 11: veículos e shell, dashboard, quilometragem. Existe agora uma fatia completa — modelo, repository, provider, tela de leitura, tela de escrita, tratamento de erro específico — e tudo que vier depois vai imitá-la. O checkpoint existe para garantir que vale a pena imitar.

## Resultado

| Verificação | Antes | Depois |
| --- | --- | --- |
| `flutter analyze` | limpo | limpo |
| `flutter test` | 158 passando | 172 passando |
| `dart format` | limpo | limpo |

Três unificações, nenhuma funcionalidade nova, nenhum comportamento perdido.

---

## O que foi unificado

### 1. Havia quatro jeitos de parsear um enum

`Vehicle` chamava `parseEnum` direto; `Alert` chamava `parseEnum` passando por um `_snakeToCamel` privado do arquivo; `OdometerSource` tinha um `fromWire` estático; `ApiErrorCode` tinha outro `fromWire`, com **uma segunda cópia** do mesmo `_snakeToCamel`.

Quatro idiomas para a mesma decisão, com dois helpers idênticos em arquivos diferentes — e os prompts 13, 15 e 17 trazem mais oito enums.

A conversão `snake_case` → `camelCase` desceu para dentro do `parseEnum`, e **todo enum de fio agora expõe um `static fromWire`**. O call site ficou igual em toda parte:

```dart
severity: AlertSeverity.fromWire(json['severity'] as String?),
```

Os dois `_snakeToCamel` sumiram. `ApiErrorCode.fromWire` manteve a lista explícita de valores em vez de usar `values`, e agora está comentado por quê: `semConexao` e `tempoEsgotado` são códigos que o app inventa para falha de rede, e precisam continuar **inalcançáveis a partir de um corpo de resposta** — senão um servidor que os enviasse faria o app afirmar que está offline.

`FuelType` ganhou `fromWireOrNull`, preservando uma distinção que já existia e vale manter: `null` é "o dono não informou", `desconhecido` é "o servidor nomeou um combustível que este build não conhece". Só o primeiro deve aparecer como campo vazio.

### 2. Dois repositories desembrulhavam a mesma resposta de jeitos diferentes

`vehicle` fazia `if (data is! List) return []` e depois um `for`; `odometer` fazia um ternário inline dentro do literal de lista. Mesma coisa, escrita duas vezes — e mais seis endpoints de coleção vêm pela frente.

Viraram `listOf(body, X.fromJson)` e `pageOf(body, X.fromJson)`, em `lib/core/network/api_envelope.dart`. Uma linha por repository, e um único lugar que sabe que a API responde `{"data": [...], "next_cursor": ...}`.

Comportamento que ficou explícito e agora tem teste: **uma entrada malformada é pulada, não fatal.** Uma linha ruim numa página de trinta custa aquela linha, não a tela.

### 3. O mesmo `if` de 422 estava escrito três vezes

`AuthFormErrors` (auth, testado), um par de ternários inline no formulário de veículo, e um acesso cru a `failure.fields['mileage_km']` na folha de quilometragem. Três implementações da mesma decisão: erro de validação vai para os campos, o resto vai para o topo do formulário.

`AuthFormErrors` virou **`ApiFormErrors`** e mudou de `lib/features/auth/application/` para `lib/core/network/` — nunca teve nada de auth, é interpretação do envelope de erro do contrato. As três telas agora chamam o mesmo helper, e os prompts 14, 16 e 17 acrescentam mais quatro formulários que já nascem certos.

Uma diferença de comportamento veio junto, de propósito: `isOffline` passou a cobrir também `tempoEsgotado`, não só `semConexao`. Um timeout também não é culpa do que a pessoa digitou, então o botão também deve virar "Tentar de novo".

---

## O que foi verificado e estava certo

**Nenhum cálculo de domínio vazou para as features.** `grep` por aritmética de data, comparação com "hoje", soma de meses e derivação de vencimento em `lib/features` devolve três ocorrências, todas legítimas e todas na folha de quilometragem: a data de hoje como valor inicial do campo, `DateTime.now()` como teto do seletor de data, e a comparação que decide entre escrever "Hoje" ou a data. Default de input e apresentação — nenhuma delas deriva estado. A regra que sustenta o produto continua de pé.

**Os modelos batem com o contrato, campo a campo.** Confrontei `Vehicle`, `OdometerReading`, `Dashboard` e `Alert` contra `test/golden/*.json` do backend: as 18 chaves de veículo, as 7 de leitura de odômetro, o `next_cursor` da página. Nada faltando, nada com tipo ou nulabilidade divergente. `fipe_code` continua sendo parseado e nunca exibido — está sempre nulo, e já estava registrado.

**As ações destrutivas confirmam, e dizem a verdade.** Excluir veículo explica que o histórico é preservado (é exclusão lógica); apagar uma leitura de odômetro avisa que some para sempre e que a quilometragem atual pode mudar. Ambas com estado de carregamento e erro tratado.

**A invalidação depois de escrever é consistente** nos dois pontos de escrita que existem, e a regra virou texto em `docs/PADROES.md`: usar o que a resposta já deu, invalidar só o que de fato mudou, refazer a busca apenas quando a resposta foi `204` e não devolveu nada.

**Nenhum código morto.** Os nove widgets do design system têm uso real agora — `AppMetric` e `AppStatusChip`, que estavam em zero na Auditoria 1, entraram com o dashboard. Nenhum TODO órfão, nenhum import não usado, nenhum arquivo vazio.

---

## Deliberadamente não extraído

**O controle de cursor de paginação.** Existe **uma** lista paginada hoje (`OdometerHistoryController`). Extrair um controlador genérico agora seria abstração antes da necessidade, e o desenho certo só aparece com o segundo caso na mão.

O gatilho está escrito em `docs/PADROES.md`: **a lista de manutenções, no Prompt 13.** Aí serão duas ocorrências reais e a extração se justifica.

---

## Cobertura acrescentada

Os quatorze testes novos são todos sobre o código compartilhado que passou a existir — código que agora várias features dependem e cuja quebra seria silenciosa:

- `parseEnum` com `snake_case`, com nome exato tendo precedência, e com sublinhados degenerados (`_`, `__`, `a__b`) sem estourar.
- `listOf` e `pageOf` com lista vazia, chave ausente, `data` que não é lista, e entrada malformada no meio.
- `ApiFormErrors` com timeout e com `409`.

---

## Próximo passo

Prompt 13 — manutenções, lista e detalhe. É a segunda lista paginada, e portanto o momento de extrair o controlador de cursor.

`docs/PADROES.md` existe agora e descreve o padrão real do código. Os prompts seguintes apontam para ele em vez de repetir instrução de arquitetura.
