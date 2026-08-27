# Padrões

O que três features (`vehicle`, `dashboard`, `odometer`) fizeram igual e virou o jeito de fazer. Consolidado na Auditoria 2. Siga isto em vez de inventar uma segunda forma; se algo aqui não servir para o seu caso, diga por quê antes de divergir.

## As quatro camadas

```
lib/features/<feature>/
├── domain/         modelos e enums; Dart puro, sem Flutter
├── data/           repository: fala HTTP, devolve modelo, lança ApiFailure
├── application/    providers Riverpod e controllers
└── presentation/   telas e widgets da feature
```

## domain — modelo

`fromJson` escrito à mão. Sem `build_runner`.

Todo enum vindo do fio termina em `desconhecido` e expõe um `static fromWire`:

```dart
enum AlertSeverity {
  vencido,
  venceEmBreve,
  desconhecido;

  static AlertSeverity fromWire(String? raw) =>
      parseEnum(raw, AlertSeverity.values, fallback: desconhecido);
}
```

`parseEnum` já converte `vence_em_breve` para `venceEmBreve` — não escreva conversão de caixa na feature. **Nunca lance ao parsear um valor de enum:** o contrato diz que um valor novo no servidor não pode quebrar um app já publicado.

Tipos: data civil é `CivilDate` (nunca `DateTime.parse().toLocal()`), timestamp é `DateTime` local, dinheiro é `Money` em centavos, distância é `int` em km.

Quando `null` e "desconhecido" são respostas diferentes, mantenha as duas — ver `FuelType.fromWireOrNull`: null é "o dono não informou", `desconhecido` é "o servidor nomeou um combustível que este build não conhece".

## data — repository

Recebe o `ApiClient`, usa `ApiPaths`, devolve modelo. Nunca monta path à mão, nunca deixa vazar `DioException`.

Listas passam pelos helpers de envelope, não por um `for` próprio:

```dart
Future<List<Vehicle>> list() async {
  final body = await api.get(ApiPaths.vehicles);
  return listOf(body, Vehicle.fromJson);          // {"data": [...]}
}

Future<CursorPage<OdometerReading>> list(String vehicleId, {int? limit, String? cursor}) async {
  final body = await api.get(
    ApiPaths.vehicleOdometer(vehicleId),
    query: api.paginationQuery(limit: limit, cursor: cursor),
  );
  return pageOf(body, OdometerReading.fromJson);  // + "next_cursor"
}
```

**Todo POST de recurso envia um `id` UUIDv7 gerado pelo cliente.** É o que torna a criação idempotente: se a conexão cair depois do envio, tentar de novo devolve o mesmo recurso com `200` em vez de criar um duplicado. Trate `200` e `201` igual. O gerador entra pelo construtor (`newId`) para o teste poder fixá-lo.

## application — providers

**Leitura de um read model:** `FutureProvider.family` pelo id do veículo.

```dart
final dashboardProvider = FutureProvider.family<Dashboard, String>((ref, vehicleId) {
  return ref.watch(dashboardRepositoryProvider).get(vehicleId);
});
```

Chavear por veículo, e não refazer a busca ao trocar de carro, é o que faz voltar ao carro anterior ser instantâneo.

**Estado que muda por ação:** `AsyncNotifier` (ou `FamilyAsyncNotifier`), como `VehiclesController` e `OdometerHistoryController`.

## presentation — tela

Duas peças, e a separação é deliberada:

- **`XView` (`ConsumerWidget`)** — assiste o provider e é dona dos estados: carregando, erro, conteúdo.
- **`XContent` (`StatelessWidget` puro)** — recebe o modelo, **não toca em `ref`**.

É isso que permite testar a copy sem `ProviderScope`. Ver `dashboard_screen.dart` e `test/features/dashboard/presentation/`.

## Erros de formulário

Uma decisão, um lugar: `ApiFormErrors`.

```dart
} on ApiFailure catch (failure) {
  setState(() {
    _submitting = false;
    _fieldErrors = ApiFormErrors.fieldsOf(failure);   // 422 -> campo a campo
    _banner = ApiFormErrors.bannerOf(failure);        // o resto -> topo do form
    _offline = ApiFormErrors.isOffline(failure);      // botão vira "Tentar de novo"
  });
}
```

As chaves de `details.fields` são as mesmas do JSON enviado — ligue direto no `errorText` do campo. **Não reescreva a mensagem do servidor:** ela já vem em pt-BR e é mais específica do que qualquer texto genérico. A exceção é `429`, onde o útil é dizer que esperar resolve.

## Invalidação depois de escrever

A regra: **use o que a resposta já deu, invalide só o que de fato mudou.**

```dart
// O POST devolveu o veículo atualizado — nada de segunda requisição.
ref.read(vehiclesProvider.notifier).applyUpdated(created.vehicle);
// Mas toda distância até um vencimento se moveu, então o read model recarrega.
ref.invalidate(dashboardProvider(vehicleId));
ref.invalidate(odometerHistoryProvider(vehicleId));
```

Quando a resposta é `204` e não devolve nada, aí sim refaça a busca (`reload()`). Não invalide o mundo: cada `invalidate` é uma requisição.

## Paginação

Hoje existe **uma** lista com cursor (`OdometerHistoryController`), então o controle de cursor mora nela mesma. **A segunda — manutenções, no Prompt 13 — é o gatilho para extrair um controlador genérico** para `lib/core`. Antes disso seria abstração sem necessidade.

O padrão de estado já está em `PagedState`: itens acumulados, `isLoadingMore`, `hasMore`, `lastPageError`. Falha ao carregar a página seguinte **nunca** apaga o que já está na tela — vira rodapé com "tentar de novo".

## O que o app não faz

Não calcula estado de domínio. `status`, `due_on`, `due_at_km`, `remaining_days`, `remaining_km`, `warranty_until` chegam prontos. Se uma tela precisa de um número que a API não devolve, registre em `docs/DECISOES-EM-ABERTO.md` — não calcule.

Aritmética de data só é aceitável como **default de input** (a data de hoje ao abrir um formulário) ou **limite de input** (não deixar escolher data futura). Nunca para derivar estado.

## Testes por camada

| Camada | O que testar |
| --- | --- |
| domain | `fromJson` completo, com todos os opcionais nulos, e com enum desconhecido caindo no fallback |
| data | só quando houver montagem de request não trivial (conversão para centavos, flags) |
| application | quando houver lógica de estado real (paginação, single-flight) |
| presentation | só o que tem decisão: frases, agrupamento, qual diálogo abre. Não teste tela que só exibe |

Toda tela nova entra no teste de 360×640 com escala de texto 1,3 nos dois temas (`test/ux/`, e o grupo equivalente em `dashboard_content_test.dart`).
