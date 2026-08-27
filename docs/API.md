# Meu Auto — mapa da API v1

Fonte da verdade: [`../meu-auto-backend/api/openapi.yaml`](../../meu-auto-backend/api/openapi.yaml).
Este arquivo é um mapa para o app. Não substitui o contrato.

Tipos Dart abaixo seguem `lib/core/domain`: `CivilDate` para data civil, `Money` para `*_cents`, `DateTime` para timestamp RFC 3339. O app ainda não existe; os nomes são o alvo, não código.

---

## 1. Autenticação

### Como autenticar

Rotas sob `/v1` que não são de auth exigem:

```
Authorization: Bearer <access_token>
```

`token_type` na sessão é sempre `Bearer`. Os endpoints de auth e as sondas (`/healthz`, `/readyz`) são públicos: o refresh token vai no JSON, não no header.

### Fluxo

1. **Cadastro** — `POST /v1/auth/register` com `name`, `email`, `password`. Responde **201** e já devolve `Session`. E-mail duplicado: **409** `conflict` (“Este e-mail já está cadastrado.”). A conta nasce ativa; não há verificação de e-mail.
2. **Login** — `POST /v1/auth/login` com `email`, `password`. Responde **200** e `Session`. E-mail inexistente e senha errada devolvem a **mesma** **401** `unauthorized` (“E-mail ou senha incorretos.”), no mesmo tempo de resposta.
3. **Uso** — cada pedido autenticado leva o access token. Quando `expires_at` chegar, chamar refresh **antes** de falhar a tela.
4. **Refresh** — `POST /v1/auth/refresh` com o `refresh_token` atual. Responde **200** e uma **nova** `Session`. O token enviado é revogado; **guarde sempre o novo**. Token inválido, expirado ou já morto: **401**.
5. **Logout** — `POST /v1/auth/logout` com o `refresh_token`. Responde **204** mesmo se o token for desconhecido (idempotente). Só encerra **essa** sessão.
6. **Reset de senha**
   - `POST /v1/auth/password-reset/request` com `email` → **202** sempre, exista ou não a conta. Corpo: `{ "message": "Se este e-mail estiver cadastrado, enviaremos um link de redefinição." }`. O link vale **1 hora** e só pode ser usado uma vez.
   - `POST /v1/auth/password-reset/confirm` com `token` e `password` → **204**. Link inválido/expirado/já usado: **401**. Redefinir **encerra todas as sessões** da conta.

### `Session`

| Campo | Tipo Dart | Nulo | Notas |
| --- | --- | --- | --- |
| `user` | `User` | não | Conta recém-autenticada |
| `token_type` | `String` (`Bearer`) | não | Fixo |
| `access_token` | `String` | não | JWT HS256; vai no header |
| `expires_at` | `DateTime` | não | Fim de vida do access token |
| `refresh_token` | `String` | não | Opaco; guardar em storage seguro; rotaciona a cada refresh |
| `refresh_expires_at` | `DateTime` | não | Fim de vida do refresh token |

`User`: `id` (UUID), `name`, `email`, `created_at` (RFC 3339). Sem `updated_at`.

### Tempos de vida

| Token | TTL | Onde está |
| --- | --- | --- |
| Access (JWT) | **15 minutos** | OpenAPI `bearerAuth` + `internal/platform/auth` `AccessTokenTTL` |
| Refresh (opaco) | **30 dias** | `RefreshTokenTTL` |
| Link de reset | **1 hora** | OpenAPI + `PasswordResetTTL` |

### Rotação e reúso do refresh

Cada refresh **revoga** o token apresentado e emite outro. O app precisa persistir o sucessor; continuar usando o anterior é reúso.

Reúso (token **já rotacionado** apresentado de novo) é tratado como captura: o servidor **encerra todas as sessões da conta**. A resposta é **401** `unauthorized` (“Sessão inválida ou expirada. Entre novamente.”). O dono precisa entrar de novo em todos os aparelhos.

Isso **não** dispara em token morto por logout, reset de senha ou revogação em massa (SPEC.md D-15). Replay de um logout que estourou o tempo numa conexão ruim só recebe 401 daquela sessão; as outras continuam.

### Rate limit

Não há header `Retry-After`. Estouro: **429** `rate_limited`.

| Endpoint | Por e-mail | Por IP | Janela | Mensagem |
| --- | --- | --- | --- | --- |
| `POST /v1/auth/login` | 10 tentativas | 60 tentativas | 15 min | “Muitas tentativas de login. Aguarde alguns minutos e tente novamente.” |
| `POST /v1/auth/password-reset/request` | 5 pedidos | 20 pedidos | 1 hora | “Muitas solicitações. Aguarde alguns minutos e tente novamente.” |

Os dois limiters de cada endpoint são consultados juntos (não há curto-circuito). Login **bem-sucedido** zera o limiter daquele e-mail. **Register, refresh e logout não têm rate limit.** Os limites do reset de senha estão no código (`internal/identity/service.go`), não na descrição do OpenAPI — ver [Dúvidas](#10-dúvidas).

O app, ao receber `rate_limited`: mostrar a `message`, bloquear o botão, tentar de novo depois (backoff simples). Não enumerar contas.

---

## 2. Convenções

### Data civil × timestamp

| | Data civil | Timestamp |
| --- | --- | --- |
| Campos | `occurred_on`, `due_on`, `starts_on`, `ends_on`, `paid_on`, `current_mileage_at`, `recorded_on`, `since`, `warranty_until`, `last_occurred_on` | `created_at`, `updated_at`, `expires_at`, `refresh_expires_at` |
| Fio | `YYYY-MM-DD` | RFC 3339 |
| Dart | `CivilDate` — **nunca** `DateTime.parse().toLocal()` | `DateTime.parse().toLocal()` é correto |
| Significado | Dia no calendário brasileiro, sem hora e sem fuso | Instante real (UTC no servidor) |

Data de ocorrência **não pode estar no futuro**. Vencimento de obrigação **pode**.

### Dinheiro e distância

- Dinheiro: inteiro em **centavos** (`*_cents`). Nunca `double`, nunca string. Dart: `Money`.
- Distância: inteiro em **quilômetros**. Dart: `int`.
- Relatório do dashboard **não** é o custo de rodar o carro. Rotular “custo registrado”. Ver `tracked_categories`.

### Paginação por cursor

Só três listas são paginadas (marcadas na tabela da seção 3):

- `GET /v1/vehicles/{vehicleId}/odometer`
- `GET /v1/vehicles/{vehicleId}/maintenance-records`
- `GET /v1/vehicles/{vehicleId}/timeline`

Query:

| Param | Padrão | Faixa | Comportamento |
| --- | --- | --- | --- |
| `limit` | 50 | 1–200 | Fora da faixa é **ajustado**, não rejeitado |
| `cursor` | ausente = primeira página | opaco | Repassar `next_cursor` sem interpretar |

Resposta: `{ "data": [...], "next_cursor": "<opaco>" | null }`. `null` é a última página. Cursor inválido: **422** `validation_failed` em `details.fields.cursor`.

`GET /v1/vehicles`, itens, planos, obrigações, seguros e alertas **não** são paginados: só `{ "data": [...] }`.

### Idempotência no POST (UUIDv7)

A convenção do contrato: `POST` de recurso aceita `id` UUIDv7 gerado pelo cliente. Reenviar a mesma requisição após queda de conexão:

- **201** — recurso criado agora
- **200** — o `id` já existia e pertence ao chamador; mesmo corpo

O OpenAPI documenta **200 e 201** só em:

- `POST /v1/vehicles`
- `POST /v1/vehicles/{vehicleId}/maintenance-records`

Os outros POSTs com `id` opcional (`odometer`, planos, obrigações, seguros) listam **apenas 201**. `POST /v1/maintenance-items` **não aceita `id`**. Ver [Dúvidas](#10-dúvidas).

`id` que já pertence a **outro** veículo/conta: **409** `conflict` (“Este identificador já está em uso. Gere outro e tente novamente.”).

UUID malformado no path: **404** `not_found`, não 422.

### Envelope de erro

Todo erro HTTP (incluindo 404 de rota inexistente e 405 de método errado) usa:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "… pt-BR …",
    "details": {}
  }
}
```

Decidir comportamento pelo `code`. Exibir `message`. Código desconhecido = falha genérica, nunca erro de parse. `details` é omitido quando vazio (`omitempty`).

Exceções de formato: `/healthz` e `/readyz` **não** usam esse envelope. `/readyz` 503 é `{ "status": "unavailable", "reason": "database" }`.

### Outras regras de fio

- Corpo JSON máximo: 32 KiB. Maior: 422.
- PATCH: campo ausente permanece. `null` no JSON, depois de decodificado, é indistinguível de “não enviado” — **não dá para limpar** opcional de veículo por PATCH.
- Recurso de outro usuário: **404**, nunca 403. Sem tela de “sem permissão”.
- Valor novo em enum: default seguro, nunca crash.
- Mensagens de erro: pt-BR. Códigos: inglês estável.

---

## 3. Endpoints

**41 operações** em **25 paths**, na mesma ordem do OpenAPI.

Auth: `pública` ou `Bearer`. Request/response são nomes de schema do OpenAPI, ou um envelope anônimo batizado aqui (seção 4). Além dos códigos da linha, qualquer rota pode devolver `internal`; path inexistente `not_found`; método errado `method_not_allowed`; JSON ilegível `validation_failed`.

### Operação

| Método | Path | Auth | Request | Response | Erros | Paginado |
| --- | --- | --- | --- | --- | --- | --- |
| GET | `/healthz` | pública | nenhum | `HealthStatus` | — | não |
| GET | `/readyz` | pública | nenhum | `ReadyStatus` (200) / `ReadyUnavailable` (503) | — (503 fora do envelope `Error`) | não |

### Auth

| Método | Path | Auth | Request | Response | Erros | Paginado |
| --- | --- | --- | --- | --- | --- | --- |
| POST | `/v1/auth/register` | pública | `RegisterRequest` | `Session` (201) | `conflict`, `validation_failed` | não |
| POST | `/v1/auth/login` | pública | `LoginRequest` | `Session` (200) | `unauthorized`, `validation_failed`, `rate_limited` | não |
| POST | `/v1/auth/refresh` | pública | `RefreshTokenRequest` | `Session` (200) | `unauthorized`, `validation_failed` | não |
| POST | `/v1/auth/logout` | pública | `RefreshTokenRequest` | `NoContent` (204) | `validation_failed` | não |
| POST | `/v1/auth/password-reset/request` | pública | `PasswordResetRequest` | `PasswordResetAccepted` (202) | `validation_failed`, `rate_limited` | não |
| POST | `/v1/auth/password-reset/confirm` | pública | `PasswordResetConfirm` | `NoContent` (204) | `unauthorized`, `validation_failed` | não |

### Conta

| Método | Path | Auth | Request | Response | Erros | Paginado |
| --- | --- | --- | --- | --- | --- | --- |
| GET | `/v1/me` | Bearer | nenhum | `User` | `unauthorized` | não |
| PATCH | `/v1/me` | Bearer | `UpdateMeRequest` | `User` | `unauthorized`, `validation_failed` | não |
| DELETE | `/v1/me` | Bearer | `DeleteMeRequest` | `NoContent` (204) | `unauthorized`, `validation_failed` | não |

`PATCH /v1/me` só altera `name`. Troca de e-mail não existe. `DELETE /v1/me` é irreversível (conta + veículos + histórico) e exige a senha atual.

### Veículos

| Método | Path | Auth | Request | Response | Erros | Paginado |
| --- | --- | --- | --- | --- | --- | --- |
| GET | `/v1/vehicles` | Bearer | nenhum | `VehicleList` | `unauthorized` | não |
| POST | `/v1/vehicles` | Bearer | `CreateVehicleRequest` | `Vehicle` (200 retry / 201) | `unauthorized`, `conflict`, `validation_failed` | não |
| GET | `/v1/vehicles/{vehicleId}` | Bearer | nenhum | `Vehicle` | `unauthorized`, `not_found` | não |
| PATCH | `/v1/vehicles/{vehicleId}` | Bearer | `UpdateVehicleRequest` | `Vehicle` | `unauthorized`, `not_found`, `validation_failed` | não |
| DELETE | `/v1/vehicles/{vehicleId}` | Bearer | nenhum | `NoContent` (204) | `unauthorized`, `not_found` | não |
| GET | `/v1/vehicles/{vehicleId}/odometer` | Bearer | nenhum (`limit`, `cursor`) | `OdometerPage` | `unauthorized`, `not_found`, `validation_failed` | **sim** |
| POST | `/v1/vehicles/{vehicleId}/odometer` | Bearer | `CreateOdometerReadingRequest` | `CreateOdometerReadingResponse` (201) | `unauthorized`, `not_found`, `conflict`, `validation_failed`, `odometer_rollback` | não |
| DELETE | `/v1/odometer/{readingId}` | Bearer | nenhum | `NoContent` (204) | `unauthorized`, `not_found` | não |

### Catálogo de veículos

| Método | Path | Auth | Request | Response | Erros | Paginado |
| --- | --- | --- | --- | --- | --- | --- |
| GET | `/v1/vehicle-brands` | Bearer | nenhum (`vehicle_type`) | `VehicleBrandList` | `unauthorized`, `validation_failed`, `upstream_unavailable` | não |
| GET | `/v1/vehicle-brands/{brandId}/models` | Bearer | nenhum | `VehicleModelList` | `unauthorized`, `not_found`, `upstream_unavailable` | não |
| GET | `/v1/vehicle-models/{modelId}/years` | Bearer | nenhum | `VehicleModelYearList` | `unauthorized`, `not_found`, `upstream_unavailable` | não |
| GET | `/v1/vehicle-model-years/{modelYearId}` | Bearer | nenhum | `VehicleModelYearDetail` | `unauthorized`, `not_found` | não |

Marca → modelo → ano → detalhe. O servidor espelha a tabela FIPE no próprio banco e busca na fonte externa só quando ainda não tem o ramo — logo, são leituras comuns, não um proxy.

Três coisas que a interface precisa respeitar:

- **`fipe_price` pode ser `null` e isso não é erro.** É a resposta documentada quando a fonte externa não responde: o resto do objeto vem do banco e o cadastro continua funcionando. `collected_at` diz quando o valor foi coletado, porque um valor guardado antes também pode ser servido.
- **O detalhe nunca devolve `upstream_unavailable`** — ele degrada. As três listas devolvem, quando não têm nada para servir.
- **`upstream_unavailable` não é `rate_limited`.** O segundo diz que *este cliente* está indo rápido demais; o primeiro é a indisponibilidade de um terceiro, e nada que a pessoa fez causou.

`year` é `null` na entrada de veículo zero-quilômetro: na fonte ela é faixa de preço, não ano. `fuel_type` já vem no vocabulário que `POST /v1/vehicles` aceita — repasse direto, sem tabela de tradução no app; `fuel_label` é a palavra da fonte, só para exibir.

No `POST`/`PATCH` de veículo o app envia **só** `catalog_model_year_id`. A marca e o modelo são derivados dele no servidor, então um trio inconsistente não é expressável daqui. Os campos de texto continuam sendo um **retrato** do que o dono confirmou, não um espelho do catálogo.

`POST /v1/vehicles` materializa os planos sugeridos (RN-09). `current_mileage_km` vira a primeira leitura, datada de hoje. `DELETE` do veículo é **lógico** (some das listas; o histórico permanece). `DELETE` da leitura é **definitivo**. Cliente só envia `source` `manual` ou `correction`.

### Manutenção

| Método | Path | Auth | Request | Response | Erros | Paginado |
| --- | --- | --- | --- | --- | --- | --- |
| GET | `/v1/maintenance-items` | Bearer | nenhum (`vehicle_type`, `kind`) | `MaintenanceItemList` | `unauthorized`, `validation_failed` | não |
| POST | `/v1/maintenance-items` | Bearer | `CreateMaintenanceItemRequest` | `MaintenanceItem` (201) | `unauthorized`, `conflict`, `validation_failed` | não |
| GET | `/v1/vehicles/{vehicleId}/maintenance-plans` | Bearer | nenhum (`include_not_applicable`) | `MaintenancePlanList` | `unauthorized`, `not_found` | não |
| POST | `/v1/vehicles/{vehicleId}/maintenance-plans` | Bearer | `CreateMaintenancePlanRequest` | `MaintenancePlanSummary` (201) | `unauthorized`, `not_found`, `conflict`, `validation_failed` | não |
| PATCH | `/v1/maintenance-plans/{planId}` | Bearer | `UpdateMaintenancePlanRequest` | `MaintenancePlanSummary` | `unauthorized`, `not_found`, `validation_failed` | não |
| DELETE | `/v1/maintenance-plans/{planId}` | Bearer | nenhum | `NoContent` (204) | `unauthorized`, `not_found` | não |
| GET | `/v1/vehicles/{vehicleId}/maintenance-profile` | Bearer | nenhum | `MaintenanceProfile` | `unauthorized`, `not_found` | não |
| POST | `/v1/vehicles/{vehicleId}/maintenance-profile/answers` | Bearer | `AnswerMaintenanceProfileRequest` | `MaintenanceProfile` (200) | `unauthorized`, `not_found`, `validation_failed` | não |
| GET | `/v1/vehicles/{vehicleId}/maintenance-records` | Bearer | nenhum (`limit`, `cursor`) | `MaintenanceRecordPage` | `unauthorized`, `not_found`, `validation_failed` | **sim** |
| POST | `/v1/vehicles/{vehicleId}/maintenance-records` | Bearer | `CreateMaintenanceRecordRequest` | `MaintenanceRecord` (200 retry / 201) | `unauthorized`, `not_found`, `conflict`, `validation_failed`, `odometer_rollback` | não |
| GET | `/v1/maintenance-records/{recordId}` | Bearer | nenhum | `MaintenanceRecord` | `unauthorized`, `not_found` | não |
| PATCH | `/v1/maintenance-records/{recordId}` | Bearer | `UpdateMaintenanceRecordRequest` | `MaintenanceRecord` | `unauthorized`, `not_found`, `validation_failed` | não |
| DELETE | `/v1/maintenance-records/{recordId}` | Bearer | nenhum | `NoContent` (204) | `unauthorized`, `not_found` | não |

Lista de planos já vem com vencimento calculado, ordenada por urgência: `vencido`, `vence_em_breve`, `sem_baseline`, `em_dia`, `sem_periodicidade`. Criar/atualizar plano devolve `MaintenancePlanSummary` (**sem** `status`/`due_*`). Qualquer edição promove `origin` para `user`. `DELETE` do plano **desativa**. `DELETE` do registro é **lógico** (retratação): a leitura de odômetro some e o relógio volta ao registro anterior. `PATCH` do registro **não altera as linhas de item**.

### Prazos

| Método | Path | Auth | Request | Response | Erros | Paginado |
| --- | --- | --- | --- | --- | --- | --- |
| GET | `/v1/vehicles/{vehicleId}/obligations` | Bearer | nenhum (`kind`) | `ObligationList` | `unauthorized`, `not_found`, `validation_failed` | não |
| POST | `/v1/vehicles/{vehicleId}/obligations` | Bearer | `CreateObligationRequest` | `Obligation` (201) | `unauthorized`, `not_found`, `conflict`, `validation_failed` | não |
| PATCH | `/v1/obligations/{obligationId}` | Bearer | `UpdateObligationRequest` | `Obligation` | `unauthorized`, `not_found`, `validation_failed` | não |
| DELETE | `/v1/obligations/{obligationId}` | Bearer | nenhum | `NoContent` (204) | `unauthorized`, `not_found` | não |
| GET | `/v1/vehicles/{vehicleId}/seguros` | Bearer | nenhum | `SeguroList` | `unauthorized`, `not_found` | não |
| POST | `/v1/vehicles/{vehicleId}/seguros` | Bearer | `CreateSeguroRequest` | `Seguro` (201) | `unauthorized`, `not_found`, `conflict`, `validation_failed` | não |
| PATCH | `/v1/seguros/{seguroId}` | Bearer | `UpdateSeguroRequest` | `Seguro` | `unauthorized`, `not_found`, `validation_failed` | não |
| DELETE | `/v1/seguros/{seguroId}` | Bearer | nenhum | `NoContent` (204) | `unauthorized`, `not_found` | não |

Um IPVA/licenciamento por tipo por ano de referência; segundo é **409**. Para desfazer pagamento: `clear_payment: true`, sem dados de pagamento junto.

### Telas (read models)

| Método | Path | Auth | Request | Response | Erros | Paginado |
| --- | --- | --- | --- | --- | --- | --- |
| GET | `/v1/vehicles/{vehicleId}/dashboard` | Bearer | nenhum (`cost_months` 1–120, padrão 12) | `Dashboard` | `unauthorized`, `not_found` | não |
| GET | `/v1/vehicles/{vehicleId}/alerts` | Bearer | nenhum | `AlertList` | `unauthorized`, `not_found` | não |
| GET | `/v1/vehicles/{vehicleId}/timeline` | Bearer | nenhum (`limit`, `cursor`) | `TimelinePage` | `unauthorized`, `not_found`, `validation_failed` | **sim** |

Alertas: só `vencido` e `vence_em_breve`. Plano `sem_baseline` **não** entra em `/alerts` nem em `dashboard.alerts.items`; vai em `needs_baseline`. Timeline: manutenções, leituras de odômetro **sem** `source_maintenance_id` (manuais/correções), pagamentos de IPVA/licenciamento. **Seguro não aparece.** Leituras geradas por manutenção não duplicam a linha.

---

## 4. Modelos

Schemas nomeados do OpenAPI (53). Campos derivados pelo servidor estão marcados. Envelopes anônimos vêm no fim.

### Auth e conta

**`RegisterRequest`** — obrigatórios: `name` (máx. 120), `email` (máx. 254), `password` (8–128; sem regra de composição).

**`LoginRequest`** — obrigatórios: `email`, `password`.

**`RefreshTokenRequest`** — obrigatório: `refresh_token`.

**`PasswordResetRequest`** — obrigatório: `email`.

**`PasswordResetConfirm`** — obrigatórios: `token`, `password` (8–128).

**`UpdateMeRequest`** — obrigatório: `name` (máx. 120).

**`DeleteMeRequest`** — obrigatório: `password`.

**`User`**

| Campo | Tipo Dart | Nulo |
| --- | --- | --- |
| `id` | `String` | não |
| `name` | `String` | não |
| `email` | `String` | não |
| `created_at` | `DateTime` | não |

**`Session`** — ver seção 1.

### Veículo

**`CreateVehicleRequest`** — obrigatórios: `brand`, `model` (máx. 120). Opcionais: `id` (UUIDv7), `vehicle_type` (omite → `car`; só `car` é aceito), `version`, `manufacture_year`, `model_year` (não anterior à fabricação; teto = ano atual + 1), `plate` (ABC1234 ou Mercosul ABC1D23; resposta em maiúsculas sem hífen), `renavam` (9–11 dígitos), `chassis` (17, sem I/O/Q), `fuel_type`, `color`, `nickname`, `current_mileage_km` (≥ 0).

**`UpdateVehicleRequest`** — todos opcionais; ausente = não muda. Não limpa opcional.

**`Vehicle`**

| Campo | Tipo Dart | Nulo | Notas |
| --- | --- | --- | --- |
| `id` | `String` | não | |
| `vehicle_type` | `VehicleType` | não | Só `car` no MVP-1 |
| `brand` | `String` | não | |
| `model` | `String` | não | |
| `version` | `String?` | sim | |
| `manufacture_year` | `int?` | sim | |
| `model_year` | `int?` | sim | |
| `plate` | `String?` | sim | |
| `renavam` | `String?` | sim | |
| `chassis` | `String?` | sim | |
| `fuel_type` | `FuelType?` | sim | No OpenAPI está `string`, não `$ref` FuelType |
| `color` | `String?` | sim | |
| `nickname` | `String?` | sim | |
| `fipe_code` | `String?` | sim | Campo existe; FIPE adiada — hoje vem `null` |
| `current_mileage_km` | `int` | não | **Derivado**: leitura de **maior `occurred_on`**, não `MAX(km)` |
| `current_mileage_at` | `CivilDate?` | sim | **Derivado**: data dessa leitura |
| `created_at` | `DateTime` | não | |
| `updated_at` | `DateTime` | não | |

**`CreateOdometerReadingRequest`** — obrigatório: `mileage_km` (≥ 0). Opcionais: `id`, `occurred_on` (padrão: hoje), `source` (`manual` \| `correction`; padrão `manual`), `notes` (máx. 500).

**`OdometerReading`**

| Campo | Tipo Dart | Nulo |
| --- | --- | --- |
| `id` | `String` | não |
| `vehicle_id` | `String` | não |
| `mileage_km` | `int` | não |
| `occurred_on` | `CivilDate` | não |
| `source` | `OdometerSource` | não |
| `notes` | `String?` | sim |
| `created_at` | `DateTime` | não |

**`CreateOdometerReadingResponse`** — `reading` (`OdometerReading`) + `vehicle` (`Vehicle` já atualizado).

**`OdometerPage`** — `data: List<OdometerReading>`, `next_cursor: String?`.

### Manutenção

**`CreateMaintenanceItemRequest`** — obrigatório: `name`. Opcionais: `kind` (omite → `maintenance`), `default_interval_km|months|days` (≥ 1). **Sem `id` do cliente.** `slug` é derivado do nome no servidor.

**`MaintenanceItem`**

| Campo | Tipo Dart | Nulo | Notas |
| --- | --- | --- | --- |
| `id` | `String` | não | |
| `slug` | `String` | não | **Derivado** no item custom |
| `name` | `String` | não | |
| `kind` | `MaintenanceItemKind` | não | |
| `vehicle_type` | `String` | não | Enum **próprio**: `car` \| `motorcycle` \| `all` — não é `VehicleType` |
| `is_custom` | `bool` | não | `true` se o usuário criou |
| `default_interval_km` | `int?` | sim | |
| `default_interval_months` | `int?` | sim | |
| `default_interval_days` | `int?` | sim | |

**`CreateMaintenancePlanRequest`** — obrigatório: `maintenance_item_id`. Opcionais: `id`, `interval_km|months|days`, `alert_km`, `alert_days`. Sem intervalos, usam-se os padrões do item.

**`UpdateMaintenancePlanRequest`** — intervalos e alertas opcionais; `clear_intervals: true` zera os três (não pode vir junto de um intervalo). Qualquer PATCH marca `origin: user`.

**`MaintenancePlanSummary`** (criação/atualização, **sem** vencimento)

| Campo | Tipo Dart | Nulo |
| --- | --- | --- |
| `id` | `String` | não |
| `maintenance_item_id` | `String` | não |
| `interval_km` | `int?` | sim |
| `interval_months` | `int?` | sim |
| `interval_days` | `int?` | sim |
| `alert_km` | `int` | não |
| `alert_days` | `int` | não |
| `origin` | `MaintenancePlanOrigin` | não |

`alert_*` omitidos na criação são **derivados** (1/10 do intervalo, clamp 100–1000 km e 1–30 dias; fallback 500 km / 15 dias).

**`MaintenancePlan`** (lista: summary + estado **calculado a cada leitura**)

| Campo | Tipo Dart | Nulo | Notas |
| --- | --- | --- | --- |
| …summary… | | | mais `item_slug`, `item_name`, `item_kind` |
| `status` | `MaintenanceStatus` | não | **Derivado** (RN-02) |
| `due_at_km` | `int?` | sim | **Derivado**. `null` = dimensão km não se aplica |
| `due_on` | `CivilDate?` | sim | **Derivado**. `null` = dimensão tempo não se aplica |
| `remaining_km` | `int?` | sim | **Derivado**. `null` ≠ zero |
| `remaining_days` | `int?` | sim | **Derivado**. `null` ≠ zero |
| `last_occurred_on` | `CivilDate?` | sim | `null` quando `sem_baseline` |
| `last_mileage_km` | `int?` | sim | |

**`MaintenanceRecordItemRequest`** — obrigatório: `maintenance_item_id`. Opcionais: `description`, `part_brand`, `cost_cents` (≥ 0), `warranty_months` (≥ 1), `warranty_km` (≥ 1).

**`CreateMaintenanceRecordRequest`** — obrigatórios: `mileage_km`, `items` (1–20; item não se repete). Opcionais: `id`, `occurred_on` (padrão hoje), `kind` (omite → `performed`), `workshop_name`, `total_cost_cents`, `notes`. A km gera leitura de odômetro (mesma RN-01).

**`UpdateMaintenanceRecordRequest`** — `occurred_on`, `mileage_km`, `workshop_name`, `total_cost_cents`, `notes`. Não mexe nas linhas.

**`MaintenanceRecordItem`**

| Campo | Tipo Dart | Nulo | Notas |
| --- | --- | --- | --- |
| `id` | `String` | não | |
| `maintenance_item_id` | `String` | não | |
| `item_slug` | `String` | não | |
| `item_name` | `String` | não | |
| `description` | `String?` | sim | |
| `part_brand` | `String?` | sim | |
| `cost_cents` | `Money?` | sim | |
| `warranty_months` | `int?` | sim | Armazenado |
| `warranty_km` | `int?` | sim | Armazenado |
| `warranty_until` | `CivilDate?` | sim | **Derivado**: `occurred_on + warranty_months` |
| `warranty_until_km` | `int?` | sim | **Derivado**: `mileage_km + warranty_km` |

**`MaintenanceRecord`**

| Campo | Tipo Dart | Nulo | Notas |
| --- | --- | --- | --- |
| `id` | `String` | não | |
| `vehicle_id` | `String` | não | |
| `occurred_on` | `CivilDate` | não | |
| `mileage_km` | `int` | não | |
| `kind` | `MaintenanceRecordKind` | não | |
| `workshop_name` | `String?` | sim | |
| `total_cost_cents` | `Money` | não | Omitido no POST vira `0` |
| `notes` | `String?` | sim | |
| `items` | `List<MaintenanceRecordItem>` | não | |
| `created_at` | `DateTime` | não | |
| `updated_at` | `DateTime` | não | |

**`MaintenanceRecordPage`** — `data`, `next_cursor`.

### Prazos

**`CreateObligationRequest`** — obrigatórios: `kind`, `reference_year` (teto = ano atual + 1), `due_on`. Opcionais: `id`, `amount_cents`, `paid_on` (não futuro), `paid_amount_cents`, `notes`.

**`UpdateObligationRequest`** — `due_on`, `amount_cents`, `paid_on`, `paid_amount_cents`, `notes`, `clear_payment`.

**`Obligation`**

| Campo | Tipo Dart | Nulo | Notas |
| --- | --- | --- | --- |
| `id` | `String` | não | |
| `vehicle_id` | `String` | não | |
| `kind` | `ObligationKind` | não | |
| `reference_year` | `int` | não | |
| `due_on` | `CivilDate` | não | |
| `amount_cents` | `Money?` | sim | |
| `paid_on` | `CivilDate?` | sim | |
| `paid_amount_cents` | `Money?` | sim | |
| `notes` | `String?` | sim | |
| `status` | `ObligationStatus` | não | **Derivado** (RN-06b) |
| `remaining_days` | `int` | não | **Derivado**; negativo se passou; também quando `pago` |
| `created_at` | `DateTime` | não | |
| `updated_at` | `DateTime` | não | |

**`CreateSeguroRequest`** — obrigatórios: `insurer_name`, `starts_on`, `ends_on` (`ends_on` ≥ `starts_on`). Opcionais: `id`, `policy_number`, `premium_cents`, `emergency_phone` (máx. 32; sem validar formato BR), `broker_name`, `broker_phone`, `notes`.

**`UpdateSeguroRequest`** — os mesmos campos, todos opcionais.

**`Seguro`**

| Campo | Tipo Dart | Nulo | Notas |
| --- | --- | --- | --- |
| `id` | `String` | não | |
| `vehicle_id` | `String` | não | |
| `insurer_name` | `String` | não | |
| `policy_number` | `String?` | sim | |
| `starts_on` | `CivilDate` | não | |
| `ends_on` | `CivilDate` | não | |
| `premium_cents` | `Money?` | sim | |
| `emergency_phone` | `String?` | sim | |
| `broker_name` | `String?` | sim | |
| `broker_phone` | `String?` | sim | |
| `notes` | `String?` | sim | |
| `status` | `SeguroStatus` | não | **Derivado** |
| `remaining_days` | `int` | não | **Derivado**; em `futuro`, conta até o **início** |
| `created_at` | `DateTime` | não | |
| `updated_at` | `DateTime` | não | |

Janela de alerta de prazo/seguro: **30 dias**.

### Telas

**`Alert`**

| Campo | Tipo Dart | Nulo | Notas |
| --- | --- | --- | --- |
| `kind` | `AlertKind` | não | |
| `severity` | `AlertSeverity` | não | Só `vencido` \| `vence_em_breve` |
| `title` | `String` | não | |
| `subtitle` | `String?` | sim | Garantia: `"Garantia"` |
| `due_on` | `CivilDate?` | sim | **Derivado** |
| `due_at_km` | `int?` | sim | **Derivado** |
| `remaining_days` | `int?` | sim | **Derivado** |
| `remaining_km` | `int?` | sim | **Derivado** |
| `reference_type` | ver enums | não | Para onde navegar |
| `reference_id` | `String` | não | Id do plano, registro, obrigação ou seguro |

Navegação: `manutencao`/`cuidado` → `maintenance_plan`; `garantia` → `maintenance_record`; `ipva`/`licenciamento` → `obligation`; `seguro` → `seguro`.

**`Dashboard`** — obrigatórios: `vehicle`, `odometer`, `alerts`, `costs` (objetos aninhados, sem schema próprio).

`vehicle`: `id`, `brand`, `model`; opcionais `version`, `nickname`, `plate`. Não é o `Vehicle` completo.

`odometer`: `current_km` (`int`); `recorded_on` (`CivilDate?`) — mesmo sentido de `Vehicle.current_mileage_at`, nome diferente.

`alerts`: `overdue`, `due_soon`, `needs_baseline` (`int`); `items` (`List<Alert>`) — só os mais urgentes. `needs_baseline` **não** entra em `items`.

`costs` (**não** é custo total de rodar):

| Campo | Tipo Dart | Notas |
| --- | --- | --- |
| `period_months` | `int` | Ecoa `cost_months` |
| `since` | `CivilDate` | Início da janela |
| `maintenance_cents` | `Money` | |
| `obligations_cents` | `Money` | |
| `seguro_cents` | `Money` | |
| `tracked_cents` | `Money` | Soma das três |
| `tracked_categories` | `List<String>` | Hoje: `manutencao`, `ipva`, `licenciamento`, `seguro` |

**`TimelineEntry`**

| Campo | Tipo Dart | Nulo | Notas |
| --- | --- | --- | --- |
| `kind` | `TimelineEntryKind` | não | Sem `seguro` |
| `id` | `String` | não | Id do recurso de origem |
| `occurred_on` | `CivilDate` | não | Em obrigação: data do **pagamento** |
| `title` | `String?` | sim | Manutenção: nomes dos itens. `null` nos outros — a UI rotula por `kind` |
| `subtitle` | `String?` | sim | Oficina / `source` da leitura / ano de referência |
| `amount_cents` | `Money?` | sim | `null` em odômetro |
| `mileage_km` | `int?` | sim | `null` em tributo |

**`TimelinePage`** — `data`, `next_cursor`.

### Erro

**`Error`** — `{ "error": { "code": ErrorCode, "message": String, "details": Map? } }`.

**`ErrorCode`** — ver seções 5 e 6.

### Envelopes anônimos (não são schema no OpenAPI)

Usados na tabela da seção 3 para nomear request/response.

| Nome no mapa | Forma |
| --- | --- |
| `nenhum` | Sem corpo |
| `NoContent` | HTTP 204, sem corpo |
| `HealthStatus` | `{ "status": "ok" }` |
| `ReadyStatus` | `{ "status": "ready" }` |
| `ReadyUnavailable` | `{ "status": "unavailable", "reason": "database" }` |
| `PasswordResetAccepted` | `{ "message": String }` |
| `VehicleList` | `{ "data": Vehicle[] }` |
| `MaintenanceItemList` | `{ "data": MaintenanceItem[] }` |
| `MaintenancePlanList` | `{ "data": MaintenancePlan[] }` |
| `ObligationList` | `{ "data": Obligation[] }` |
| `SeguroList` | `{ "data": Seguro[] }` |
| `AlertList` | `{ "data": Alert[] }` |

---

## 5. Enums

Valores transcritos do OpenAPI. Valor desconhecido → default seguro, nunca exception.

### `VehicleType`

| Valor | Significado |
| --- | --- |
| `car` | Carro. **Único** valor aceito no cadastro no MVP-1 |

### `FuelType`

| Valor | Significado |
| --- | --- |
| `flex` | Flex |
| `gasolina` | Gasolina |
| `etanol` | Etanol |
| `diesel` | Diesel |
| `gnv` | GNV |
| `eletrico` | Elétrico |
| `hibrido` | Híbrido |

### `OdometerSource`

| Valor | Significado | Quem escreve |
| --- | --- | --- |
| `manual` | Leitura informada pelo dono | Cliente |
| `correction` | Força uma km que violaria os vizinhos (painel trocado / valor anterior errado) | Cliente |
| `maintenance` | Gerada por um registro de manutenção | Servidor |
| `abastecimento` | Reservado ao módulo de combustível (MVP-2) | Servidor; hoje não há endpoint |

No `CreateOdometerReadingRequest`, o enum do campo `source` é só `[manual, correction]`.

### `MaintenanceItemKind`

| Valor | Significado |
| --- | --- |
| `maintenance` | Serviço no histórico |
| `care` | Hábito recorrente (calibrar, lavar). Mesmo motor de vencimento |

### `MaintenanceRecordKind`

| Valor | Significado |
| --- | --- |
| `performed` | Serviço que aconteceu e pode ser comprovado. Padrão se omitido |
| `declared` | Afirmação de memória — baseline de carro usado, sem recibo (RN-03) |

### `MaintenancePlanOrigin`

| Valor | Significado |
| --- | --- |
| `suggested` | Materializado do catálogo no cadastro do veículo |
| `user` | Criado ou editado pelo dono. Qualquer PATCH promove para cá |

### `MaintenanceStatus`

Calculado, nunca armazenado.

| Valor | Significado |
| --- | --- |
| `vencido` | Algum limite foi ultrapassado (`remaining <= 0` em km ou dias) |
| `vence_em_breve` | Algum limite está dentro de `alert_km` / `alert_days` |
| `em_dia` | Nada perto |
| `sem_baseline` | Há regra, mas nenhum registro ainda. **Não é alerta** — é pedido de configuração |
| `sem_periodicidade` | Plano só agrupa histórico e nunca vence. Estado válido, não dado faltando |

### `ObligationKind`

| Valor | Significado |
| --- | --- |
| `ipva` | IPVA do ano de referência |
| `licenciamento` | Licenciamento do ano de referência |

### `ObligationStatus`

Derivado. Janela: 30 dias.

| Valor | Significado |
| --- | --- |
| `pago` | Há `paid_on`. Prevalece sobre a data — pago em atraso continua `pago` |
| `vencido` | Não pago e `remaining_days < 0` (já passou do dia) |
| `vence_em_breve` | Não pago e 0 ≤ `remaining_days` ≤ 30. **Vencendo hoje entra aqui**, não em `vencido` |
| `pendente` | Não pago e falta mais de 30 dias |

### `SeguroStatus`

Derivado. Janela: 30 dias até `ends_on`.

| Valor | Significado |
| --- | --- |
| `futuro` | Contratado, `today < starts_on`. `remaining_days` conta até o início |
| `vigente` | Em vigor, com folga |
| `vence_em_breve` | Em vigor, acaba em ≤ 30 dias (incluindo o último dia) |
| `vencido` | Período acabou — o carro está **sem cobertura** |

### `AlertKind`

| Valor | Significado | `reference_type` |
| --- | --- | --- |
| `manutencao` | Plano `kind=maintenance` vencido/vencendo | `maintenance_plan` |
| `cuidado` | Plano `kind=care` vencido/vencendo | `maintenance_plan` |
| `garantia` | Garantia de linha de registro vencendo/vencida | `maintenance_record` |
| `ipva` | Obrigação IPVA | `obligation` |
| `licenciamento` | Obrigação licenciamento | `obligation` |
| `seguro` | Apólice | `seguro` |

### `AlertSeverity`

| Valor | Significado |
| --- | --- |
| `vencido` | Já passou |
| `vence_em_breve` | Dentro da antecedência. Um alerta **sempre** pede ação |

### `TimelineEntryKind`

| Valor | Significado |
| --- | --- |
| `manutencao` | Registro de manutenção |
| `odometro` | Leitura não gerada por manutenção |
| `ipva` | Pagamento de IPVA |
| `licenciamento` | Pagamento de licenciamento |

Não há `seguro` na timeline.

### `ErrorCode`

| Valor | HTTP típico |
| --- | --- |
| `validation_failed` | 422 |
| `unauthorized` | 401 |
| `forbidden` | 403 (no enum; ownership usa 404 — ver seção 6) |
| `not_found` | 404 |
| `method_not_allowed` | 405 |
| `conflict` | 409 |
| `odometer_rollback` | 422 |
| `rate_limited` | 429 |
| `upstream_unavailable` | 503 |
| `internal` | 500 |

### Enums só no fio (não são schema próprio)

| Onde | Valores |
| --- | --- |
| `Session.token_type` | `Bearer` |
| `Alert.reference_type` | `maintenance_plan`, `maintenance_record`, `obligation`, `seguro` |
| `MaintenanceItem.vehicle_type` | `car`, `motorcycle`, `all` |
| `CreateOdometerReadingRequest.source` | `manual`, `correction` |

---

## 6. Erros

O app decide pelo `code`, mostra `message`, trata código desconhecido como falha genérica.

| `ErrorCode` | O que o app faz |
| --- | --- |
| `validation_failed` | Ligar `details.fields` nos inputs (mesma chave do JSON enviado). Não navegar embora |
| `unauthorized` | Sessão inválida/expirada, senha de exclusão errada, ou credencial de login. Fora de auth: tentar refresh; se falhar, ir para login. Em login: mostrar a mensagem, **não** dizer se o e-mail existe. Em reset confirm: link inválido — pedir novo |
| `forbidden` | Tratar como falha genérica. **Não** montar tela de “sem permissão”. Ownership de veículo é 404 |
| `not_found` | Recurso sumiu, id malformado, ou não é do usuário. Voltar / empty state. Não distinguir os três |
| `method_not_allowed` | Bug do cliente (método errado). Falha genérica + log |
| `conflict` | Duplicata: e-mail, id de outro dono, segundo IPVA do mesmo ano, plano duplicado para o item, slug de item custom. Mostrar `message`; no cadastro de conta, oferecer login |
| `odometer_rollback` | Mostrar `message` e o vizinho em `details`. Oferecer reenvio com `source: correction` se o dono confirma painel trocado / valor errado |
| `rate_limited` | Mostrar `message`, recuar tentativas (login / reset). Sem `Retry-After` |
| `internal` | Mostrar `message` (“Ocorreu um erro inesperado. Tente novamente.”). Guardar `details.request_id` para suporte |

### `details` em `validation_failed`

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Não foi possível criar a conta.",
    "details": {
      "fields": {
        "email": "Informe um e-mail válido.",
        "password": "A senha deve ter pelo menos 8 caracteres."
      }
    }
  }
}
```

Todos os campos rejeitados de uma vez. A chave é a do JSON enviado (`brand`, `cursor`, `items`, …). Corpo vazio ou JSON inválido pode vir sem `fields`.

### `details` em `odometer_rollback`

Duas formas, conforme o vizinho que conflitou. Golden e código (não o exemplo antigo do SPEC.md §7).

Menor que o **anterior**:

```json
{
  "error": {
    "code": "odometer_rollback",
    "message": "A quilometragem informada é menor que a do registro anterior.",
    "details": {
      "previous_mileage_km": 98200,
      "previous_occurred_on": "2026-08-10",
      "submitted_mileage_km": 90000,
      "hint": "Se o painel foi trocado ou o valor anterior estava errado, reenvie com source \"correction\"."
    }
  }
}
```

Maior que o **posterior**:

```json
{
  "error": {
    "code": "odometer_rollback",
    "message": "A quilometragem informada é maior que a de um registro posterior.",
    "details": {
      "next_mileage_km": 100000,
      "next_occurred_on": "2026-08-20",
      "submitted_mileage_km": 110000,
      "hint": "Se o painel foi trocado ou o valor posterior estava errado, reenvie com source \"correction\"."
    }
  }
}
```

`source: correction` **pula** essa checagem. O mesmo 422 pode sair de `POST .../odometer` e de criar/atualizar manutenção (a km do registro gera leitura).

### `details` em `internal`

```json
{
  "error": {
    "code": "internal",
    "message": "Ocorreu um erro inesperado. Tente novamente.",
    "details": {
      "request_id": "…"
    }
  }
}
```

`request_id` só se o middleware tiver gerado um. A causa real não vai ao cliente.

---

## 7. Regras do servidor que a interface precisa refletir

### Odômetro (RN-01)

A verdade é o histórico de leituras, não o cache. `current_mileage_km` é a leitura de **data mais recente** (desempate: `created_at`), não a de maior km.

A validação compara com os **vizinhos no tempo**:

`leitura_anterior.km ≤ nova.km ≤ leitura_posterior.km`

Lançar hoje uma km de três meses atrás é válido se couber entre os registros daquela data. Sem vizinho de um lado, aquele lado não restringe. Violação → `odometer_rollback`; o dono pode forçar com `correction`. Todo evento que informa km (manutenção hoje; abastecimento no MVP-2) gera leitura na mesma transação.

### Motor de vencimento (RN-02)

Nada de `status`/`due_*` é armazenado. O servidor calcula a cada leitura. O app **não recalcula**.

Para cada plano ativo:

- Sem `interval_km`, `interval_months` e `interval_days` → `sem_periodicidade`.
- Com intervalo e sem último registro daquele item → `sem_baseline`.
- Senão: `due_km = last.km + interval_km`; `due_date = last.data + months` (fim de mês com clamp, não `AddDate` do Dart) `+ days`; `remaining = due − atual`. Status = o **pior** entre a dimensão km e a de tempo (OU). `remaining <= 0` → `vencido`; senão `remaining <= alert` → `vence_em_breve`; senão `em_dia`.

`null` em `due_at_km` / `remaining_km` / `due_on` / `remaining_days` significa “essa dimensão não se aplica”, nunca zero.

Na manutenção, **vencer hoje é `vencido`** (`remaining_days <= 0`). Isso é diferente do IPVA (abaixo).

Hábitos (`care`) usam o mesmo motor, em geral só com `interval_days`.

### `sem_baseline` não é alerta

É pedido de configuração: “quando foi a última troca?”. Não entra em `/alerts` nem em `dashboard.alerts.items`. O dashboard só **conta** em `needs_baseline`. A UI deve pedir um registro `declared` (RN-03), não um sino vermelho.

### Garantia (RN-05)

`warranty_months` / `warranty_km` vivem na linha do registro. `warranty_until` / `warranty_until_km` são derivados na leitura. Alerta `kind: garantia` aponta para o **registro**, não para uma entidade garantia.

### Pagamento e “hoje” nos prazos (RN-06b)

IPVA/licenciamento: **pagamento quita**, mesmo atrasado → `pago`. Os `remaining_days` continuam vindo (podem ser negativos) para a tela dizer “pago com 3 dias de atraso”.

**Vencendo hoje** (`remaining_days == 0`) é `vence_em_breve`, **não** `vencido` — ainda há horas para pagar.

Seguro: `vencido` = sem cobertura. `futuro` = renovação já contratada que ainda não vigora.

### Planos no cadastro (RN-09)

Ao criar o veículo, o servidor materializa um plano `origin: suggested` para cada item do catálogo com `suggest_by_default` e `vehicle_type` `car` ou `all`. São sugestões de mercado, não especificação de fábrica — a UI deve tratá-los como editáveis/desativáveis, não como verdade do fabricante. Itens com `suggest_by_default = false` (ex.: `personalizada`) não nascem sozinhos.

---

## 8. O que a API NÃO oferece

Não inventar tela, endpoint ou cálculo local para isto.

**MVP-2 / adiado (SPEC.md §9, CLAUDE.md):**

- Abastecimento e combustível (enum `abastecimento` no odômetro existe; não há rota)
- Despesas avulsas: estacionamento, pedágio, lavagem, multa, outros
- Fotos, recibos, anexos, CRLV, object storage
- Notificações push ou e-mail além do link de reset
- Cadastro de moto (`vehicle_type` no veículo só aceita `car`)
- Troca de e-mail
- Verificação de e-mail no cadastro
- Login social
- Transferência de veículo / unicidade de placa e chassi
- Operação offline e resolução de conflito
- Consumo médio e custo por km
- Relatório de “custo total de rodar” — só `tracked_cents` das categorias listadas
- Integração FIPE (campo `fipe_code` vem `null`)
- Calendário oficial de IPVA/licenciamento (o dono informa as datas)
- SENATRAN / DETRAN
- Parcelamento de IPVA
- Amortização do prêmio no custo mensal
- Editar linhas de um registro de manutenção
- Limpar campo opcional do veículo (voltar `plate` etc. para vazio)
- Atualização em lote dos intervalos `suggested`
- `vehicle_components` (posição de pneu, troca parcial)

**Não existe na API v1:**

- Troca de senha autenticada (só o fluxo de reset por e-mail)
- Listagem paginada de veículos
- Seguro na timeline
- `sem_baseline` como alerta
- Header `Retry-After`
- Endpoint de “custo/km” ou média de consumo

---

## 9. Catálogo de manutenção

Semeado em `db/migrations/000005_maintenance_catalog.up.sql`. Intervalos genéricos de mercado, **não** de fabricante. `Sugerido` = ganha plano no cadastro do veículo (`suggest_by_default`).

| Slug | Nome | Tipo | km | meses | dias | Sugerido | `vehicle_type` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `troca_oleo` | Troca de óleo do motor | `maintenance` | 10000 | 12 | — | sim | `car` |
| `filtro_oleo` | Filtro de óleo | `maintenance` | 10000 | 12 | — | sim | `car` |
| `filtro_ar` | Filtro de ar do motor | `maintenance` | 20000 | 24 | — | sim | `car` |
| `filtro_cabine` | Filtro do ar-condicionado | `maintenance` | 20000 | 12 | — | sim | `car` |
| `filtro_combustivel` | Filtro de combustível | `maintenance` | 20000 | 24 | — | sim | `car` |
| `velas` | Velas de ignição | `maintenance` | 40000 | 48 | — | sim | `car` |
| `correia_dentada` | Correia dentada | `maintenance` | 60000 | 48 | — | sim | `car` |
| `fluido_freio` | Fluido de freio | `maintenance` | 40000 | 24 | — | sim | `car` |
| `pastilhas_freio` | Pastilhas de freio | `maintenance` | 30000 | — | — | sim | `car` |
| `discos_freio` | Discos de freio | `maintenance` | 60000 | — | — | não | `car` |
| `pneus` | Pneus | `maintenance` | 50000 | — | — | sim | `car` |
| `rodizio_pneus` | Rodízio de pneus | `maintenance` | 10000 | — | — | sim | `car` |
| `alinhamento` | Alinhamento | `maintenance` | 10000 | — | — | sim | `car` |
| `balanceamento` | Balanceamento | `maintenance` | 10000 | — | — | sim | `car` |
| `fluido_arrefecimento` | Fluido de arrefecimento | `maintenance` | 60000 | 48 | — | sim | `car` |
| `oleo_cambio` | Óleo do câmbio | `maintenance` | 60000 | 48 | — | não | `car` |
| `bateria` | Bateria | `maintenance` | — | 36 | — | sim | `car` |
| `amortecedores` | Amortecedores | `maintenance` | 60000 | — | — | não | `car` |
| `palhetas` | Palhetas do limpador | `maintenance` | — | 12 | — | sim | `car` |
| `revisao` | Revisão programada | `maintenance` | 10000 | 12 | — | sim | `car` |
| `personalizada` | Manutenção personalizada | `maintenance` | — | — | — | não | `car` |
| `calibrar_pneus` | Calibrar os pneus | `care` | — | — | 15 | sim | `all` |
| `verificar_oleo` | Verificar o nível do óleo | `care` | — | — | 30 | sim | `all` |
| `verificar_arrefecimento` | Verificar o líquido de arrefecimento | `care` | — | — | 30 | sim | `all` |
| `verificar_pneus` | Verificar o desgaste dos pneus | `care` | — | — | 30 | não | `all` |
| `lavar_carro` | Lavar o carro | `care` | — | — | 15 | não | `all` |

26 itens. `personalizada` não vence (RN-02) e é a saída para o que o catálogo não nomeia. Itens `care` com `vehicle_type: all` entram no carro novo se `sugerido = sim`.

---

## 10. Dúvidas

Registradas também em `docs/DECISOES-EM-ABERTO.md`. Enquanto não houver decisão, seguir a alternativa barata.

1. **200 vs 201** — O contrato só documenta retry 200 em veículos e registros de manutenção. Os outros POSTs com `id` listam só 201. O app trata **200 e 201** como sucesso no mesmo parser, sem depender do status para saber se “já existia”.
2. **Rate limit do reset** — Não está na descrição do OpenAPI; os números (5/e-mail/h, 20/IP/h) vêm do código. O app só precisa tratar `rate_limited`.
3. **`Vehicle.fuel_type`** — Schema é `string` nullable, não `$ref: FuelType`. Parsear como `FuelType` com default seguro.
4. **`POST /v1/maintenance-items`** — Sem `id` do cliente. Retry após timeout pode criar duplicata (o servidor responde 409 se o slug colidir). Gerar o nome de forma estável ou avisar o dono.
5. **Exemplo de `odometer_rollback` no SPEC.md §7** — Desatualizado (`current_mileage_km`). Seguir OpenAPI, golden e código (`previous_*` / `next_*`).

---

## Contagem (validação)

| | OpenAPI | Este mapa |
| --- | --- | --- |
| Paths (`paths:` em `openapi.yaml`) | **25** | 25 (tabelas da seção 3) |
| Operações (método + path) | **41** | 41 linhas |
| Schemas nomeados | **53** | seção 4 + enums na 5 |
| Arquivos Dart criados | — | nenhum |

Quebra das 41 operações: operação 2, auth 6, conta 3, veículos 8, manutenção 11, prazos 8, telas 3.

Enums da seção 5 conferidos contra `components/schemas` em `api/openapi.yaml` (26-08-2026).
