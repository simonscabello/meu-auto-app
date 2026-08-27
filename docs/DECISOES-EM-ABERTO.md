# Decisões em aberto

Este arquivo registra incompatibilidades entre o que o app precisa e o que a API oferece, para que o trabalho continue sem parar: anote o gap, siga com a alternativa menos custosa e deixe a decisão explícita para resolver depois.

Consolidado no fechamento do MVP (2026-08-26). Quatro seções:

1. **[Para o repositório do backend](#para-o-repositório-do-backend)** — o que precisa ser levado para o outro repositório. Nada aqui se resolve neste.
2. **[Bloqueando o app](#bloqueando-o-app)** — o que impede um item de fechar aqui, e quem decide.
3. **[Confronto com o contrato](#confronto-com-o-contrato--fechamento-do-mvp)** — endpoint por endpoint: o que o app consome, o que não consome e por quê.
4. **[Contrato × app](#contrato--app)** — o histórico de gaps encontrados e a alternativa adotada em cada um.

---

## Para o repositório do backend

Quatro pontos para levar a `meu-auto-backend`. **Nenhum deles se resolve neste repositório** — estão aqui para não se perderem entre uma sessão e outra. Nada foi alterado lá.

### 1. O `CLAUDE.md` e o `SPEC.md` do backend descrevem um client que não existe

Os dois afirmam que o app "gera o client Dart com openapi-generator". **Não é o que foi feito.** Os modelos são escritos à mão, sem `build_runner`, sem `json_serializable`, sem gerador.

O motivo é de correção, não de gosto: o contrato exige que um valor de enum desconhecido caia num default seguro em vez de lançar — um servidor que passa a devolver `fuel_type: "hidrogenio"` não pode quebrar um app já publicado. No `json_serializable` isso é opt-in por enum (`unknownEnumValue`), fácil de esquecer num enum novo, e o esquecimento só aparece em produção.

A compensação está no lugar: `test/contract/openapi_paths_test.dart` lê o `openapi.yaml` do backend e falha se o app referenciar uma rota que não existe no contrato.

**O que fazer:** corrigir a frase nos dois arquivos. Enquanto ela estiver lá, o próximo agente que abrir o repositório do backend parte de uma premissa errada sobre como o app consome a API.

### 2. Falta o GET individual de `maintenance-plans/{id}`

`obligations/{id}` e `seguros/{id}` passaram a ter GET. `maintenance-plans/{id}` ainda só expõe `PATCH` e `DELETE`.

Consequência: o detalhe de um plano continua procurando o id na lista do veículo. Um alerta de obrigação ou seguro agora abre o GET direto.

**O que fazer:** acrescentar `GET /v1/maintenance-plans/{id}`, devolvendo o mesmo shape que a lista devolve por item.

### 3. `PATCH` não consegue limpar campo opcional do veículo

No `PATCH /v1/vehicles/{id}`, `null` significa "não altere". Não existe flag `clear_*` para os campos opcionais.

Consequência: **apelido e placa não podem ser apagados pelo app.** Quem cadastrou um apelido consegue trocá-lo, nunca voltar a não ter um. O mesmo vale para placa, cor, renavam e chassi. Não há string vazia que resolva sem ambiguidade — `""` como "limpe" colidiria com validação de formato.

**O precedente já existe no próprio contrato:** `UpdateObligationRequest` aceita `clear_payment: true` justamente para desfazer um pagamento. A forma está decidida — falta aplicá-la aos campos opcionais do veículo.

**O que fazer:** seguir o mesmo padrão (`clear_nickname`, `clear_plate`, …) ou generalizar num array (`clear: ["nickname", "plate"]`). O app não tem como contornar isso sozinho.

### 4. ~~`fipe_code` está na resposta e em nenhum request~~ — RESOLVIDO

Era peso morto: `Vehicle` devolvia `fipe_code`, nenhum request aceitava, e o campo vinha sempre nulo.

**Resolvido dos dois lados.** O backend ganhou o catálogo de veículos (`/v1/vehicle-brands`, `/v1/vehicle-brands/{id}/models`, `/v1/vehicle-models/{id}/years`, `/v1/vehicle-model-years/{id}`), espelhado da tabela FIPE no próprio Postgres, e `POST`/`PATCH /v1/vehicles` passaram a aceitar `catalog_model_year_id` e `fipe_code`. O app tem `lib/features/catalog` e o seletor progressivo no formulário de veículo.

O que fica registrado da decisão, porque volta a ser pergunta se alguém mexer:

- `fipe_code` continua sendo enviado **pelo cliente**, não lido do catálogo no servidor. É de propósito: os campos de texto do veículo são um retrato do que o dono confirmou, e não uma consulta que se atualiza sozinha quando o fornecedor renomeia a descrição.
- Os três `catalog_*_id` são **sempre anuláveis**. Veículo digitado à mão é veículo de primeira classe.
- O app manda **um** id só. Marca e modelo são derivados no servidor.

---

## Bloqueando o app

### Ícone e splash — falta arte, e nada será inventado

**Este é o único item que impede o app de ir para a loja.**

O `flutter_launcher_icons` e o `flutter_native_splash` não foram adicionados, e é de propósito: sem uma imagem de origem eles não têm o que gerar. O app usa hoje o ícone padrão do Flutter e a splash padrão.

Inventar um logo é explicitamente proibido — `CLAUDE.md`, "Things not to invent", e `PRODUCT.md` registra que não existem ativos de marca. Gerar um "provisório" seria pior do que não ter: vira o ícone que ninguém troca.

**O que decidir, e quem:** o dono do produto precisa fornecer **um PNG quadrado de 1024×1024, sem transparência nas bordas, com margem de segurança para o recorte circular do Android**. Com esse arquivo em `assets/`, o resto é mecânico:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.4
  flutter_native_splash: ^2.4.6
```

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

A cor da splash sai do tema (`AppColors`), não é escolha nova. **Sem a arte, nada disso deve ser rodado.**

### ~~IPVA, licenciamento e seguro não têm tela~~ — RESOLVIDO

As telas estão em `lib/features/obligation/`. Cuidados tem a seção "Documentos e prazos"; `/obrigacoes/:id` e `/seguros/:id` abrem o detalhe; o Quick Add oferece registrar os três.

### Troca de senha para quem está logado

Não existe `POST /v1/me/password` nem equivalente. Quem está logado e quer trocar a senha precisa usar o fluxo de recuperação por e-mail. O app não oferece a ação no Perfil, porque não há o que chamar.

**O que decidir:** se vale um endpoint (senha atual + senha nova, autenticado, encerrando as outras sessões) antes de publicar.

### Migrações adiadas de propósito

`flutter_riverpod` 3.4.2 e `go_router` 18.0.0 estão disponíveis e resolvíveis. **Decisão tomada na Auditoria 1 e não relitigada: ficar na 2.x / 17.x até o MVP fechar.** Não é dívida esquecida, é sequenciamento — trocar a biblioteca de estado no meio dos prompts de feature troca um custo conhecido por um risco desconhecido.

`intl` fica em 0.20.2 porque é o que o `flutter_localizations` do SDK fixa. Subir para 0.20.3 quebra o version solving.

**O que decidir:** abrir uma tarefa dedicada para as duas migrações depois que o MVP estiver publicado.

---

---

## Confronto com o contrato — fechamento do MVP

`docs/API.md` declara **41 operações em 25 paths**. Percorridas uma a uma contra `openapi.yaml` e contra o que os repositórios em `lib/features/*/data/` realmente chamam:

| Grupo | No contrato | Consumidas | Não consumidas |
| --- | --- | --- | --- |
| Operação (`/healthz`, `/readyz`) | 2 | 0 | 2 — probes de ops, não do app |
| Auth | 6 | 6 | — |
| Conta | 3 | 3 | — |
| Veículos | 8 | 8 | — |
| Manutenção | 11 | 11 | — |
| Prazos (obligations, seguros) | 8 | 8 | — |
| Telas (read models) | 3 | 2 | 1 — `GET /alerts` |
| **Total** | **41** | **38** | **3** |

**Nenhuma rota inexistente é chamada.** `test/contract/openapi_paths_test.dart` prova isso a cada `flutter test`: lê o `openapi.yaml` do repositório irmão e falha se `ApiPaths` referenciar um path que não está lá. O teste roda de verdade (não é pulado) quando `../meu-auto-backend` está clonado — que é o caso.

Métodos conferidos um a um, não só paths. Dois pontos que valem registro porque parecem erro e não são:

- **`maintenance-plans/{id}` só tem `PATCH` e `DELETE`.** O app nunca faz `GET` nele — `PlanDetailScreen` acha o plano dentro da lista. Não é preguiça, é o que o contrato permite (ver seção 2 acima). `obligations/{id}` e `seguros/{id}` têm GET e o detalhe usa.
- **`GET /v1/vehicles/{id}/alerts` não é chamado** porque `GET /dashboard` já devolve `alerts` embutido. Chamar os dois seria uma volta de rede a mais para o mesmo dado, e abriria a chance de as duas telas discordarem.

Query params conferidos contra o contrato: `cost_months` no dashboard, `vehicle_type` e `kind` em `maintenance-items`, `limit`/`cursor` nas três listas paginadas.

### Nenhuma regra de negócio do backend foi reimplementada

Varredura em `lib/features` por soma de meses, comparação com "hoje", cálculo de vencimento e de garantia:

- Os quatro `DateTime.now()` que sobraram são **limites de date picker** (`firstDate`/`lastDate`), hoje concentrados em `pickPastDate()`. Nenhum decide status.
- `status`, `due_on`, `due_at_km`, `remaining_days`, `remaining_km`, `warranty_until` e `warranty_until_km` são **lidos** do JSON, nunca calculados.
- O item de manutenção não ganha rótulo "garantia ativa/vencida" no app: isso exigiria comparar com hoje, e a regra é do servidor (ver tabela abaixo).

---

## Contrato × app

| Data | Assunto | Situação | O que decidir |
| --- | --- | --- | --- |
| 2026-08-26 | POST 200 vs 201 | O contrato só documenta retry `200` em `POST /v1/vehicles` e `POST /v1/vehicles/{id}/maintenance-records`. Odômetro, planos, obrigações e seguros listam só `201`, mesmo com `id` do cliente. | Tratar 200 e 201 como sucesso no mesmo parser. Não usar o status para ramificar UI. |
| 2026-08-26 | Rate limit do reset de senha | OpenAPI declara `429` em `password-reset/request`, mas não os tetos. O código limita 5/e-mail/hora e 20/IP/hora. | O app só reage a `rate_limited`. Não hardcodar os números na UI. |
| 2026-08-26 | `Vehicle.fuel_type` | OpenAPI tipa como `string` nullable, não `$ref: FuelType`. Os valores no fio são os do enum. | Parsear como `FuelType` com default seguro para valor desconhecido. |
| 2026-08-26 | Item de catálogo custom sem `id` | `CreateMaintenanceItemRequest` não aceita UUIDv7. Retry após timeout pode duplicar (ou `409` se o slug colidir). | Não prometer idempotência nessa tela; avisar se o 409 aparecer. |
| 2026-08-26 | Exemplo de `odometer_rollback` no SPEC.md | SPEC.md §7 ainda mostra `current_mileage_km` / `current_mileage_at`. OpenAPI, golden e código usam `previous_*` / `next_*`. | Seguir o OpenAPI. Ignorar o exemplo do SPEC. |
| 2026-08-26 | Riverpod 2.6.1 × 3.4.2 | A 3.x está disponível e muda a API de `AsyncNotifier` e de providers. Hoje existem 4 providers; no fim do MVP serão ~40, então este seria o momento barato de migrar. | **Decisão tomada na Auditoria 1: ficar na 2.x até o MVP fechar.** Trocar a biblioteca de estado no meio de 14 prompts de feature troca um custo conhecido por um risco desconhecido. Reabrir como tarefa dedicada depois do Prompt 22. |
| 2026-08-26 | go_router 17.5.0 × 18.0.0 | Major novo disponível e resolvível. | Mesma decisão e mesmo motivo do Riverpod: adiado para depois do MVP. Não é dívida esquecida, é sequenciamento. |
| 2026-08-26 | `odometer_rollback` tem duas formas, o OpenAPI documenta uma | `CheckOdometerConsistency` rejeita tanto contra o vizinho ANTERIOR (`previous_mileage_km`, `previous_occurred_on`) quanto contra o POSTERIOR (`next_mileage_km`, `next_occurred_on`). O `openapi.yaml` só traz o exemplo do anterior. | O app trata as duas e escreve frases diferentes para cada uma. Vale acrescentar o segundo exemplo ao contrato — quem gerar client a partir dele hoje não descobre a outra forma. |
| 2026-08-26 | Apagar leitura de odômetro não é restrito por origem | `DELETE /v1/odometer/{id}` é `DELETE ... WHERE id = $1`, sem filtrar `source`. Dá para apagar uma leitura gerada por manutenção, deixando o registro de serviço sem a quilometragem que o sustenta. | **O app guarda isso do lado dele** (só oferece apagar em `manual` e `correction`; nas demais mostra cadeado e explica). Candidato a `422` no servidor — hoje a regra existe só no cliente, e outro cliente não a respeitaria. |
| 2026-08-26 | O `hint` do rollback é instrução de cliente, não texto de usuário | `details.hint` diz literalmente `reenvie com source "correction"`. | Não exibir. O app escreve a própria frase e oferece o override como botão. Coberto por teste. |
| 2026-08-26 | Editar manutenção não tem como forçar um `odometer_rollback` | `POST /v1/vehicles/{id}/odometer` aceita `source: "correction"` para forçar um valor rejeitado. `PATCH /v1/maintenance-records/{id}` passa pela **mesma** validação de vizinhos, mas o `UpdateMaintenanceRecordRequest` não tem campo equivalente. Corrigir a data ou a km de um registro antigo pode ficar impossível pelo app. | O app mostra o conflito com os números reais e oferece só "Corrigir o valor" (`allowOverride: false`) — dar um botão que não funciona seria pior. Candidato a aceitar `source` também no PATCH. |
| 2026-08-26 | O item de manutenção não traz estado da garantia | `MaintenanceRecordItem` devolve `warranty_until` e `warranty_until_km` derivados, mas nenhum status. Dizer "ativa" ou "vencida" na tela exigiria comparar com hoje — e essa regra é do servidor, que já a responde em `/alerts` com `kind: garantia`. | A tela mostra só o fato ("Garantia até 20/08/2028 ou até 138.200 km"). Se quisermos o estado, o certo é a API devolvê-lo no item, não o app recalcular e passar a discordar da lista de alertas. |
| 2026-08-26 | Criar manutenção não tem como forçar um `odometer_rollback` | O diálogo compartilhado oferece "o valor está certo". `POST /odometer` honra `source: "correction"`. `CreateMaintenanceRecordRequest` não tem campo equivalente e `CreateRecord` sempre chama `CheckOdometerConsistency`. Reenviar o formulário (o que o Prompt 14 pede) bate na mesma 422. | O app reenvia o body inteiro, sem inventar `source`. No backend real o segundo POST falha de novo até o contrato ganhar um skip. Candidato a aceitar `source` também no POST de registro. |
| 2026-08-26 | Erro de item no POST não vem indexado | O Prompt 14 espera `items.0.warranty_months`. O servidor hoje grava tudo em `details.fields.items`. | O app liga as duas formas: chave indexada no cartão da linha; `items` no bloco "O que foi feito". |
| 2026-08-26 | Troca de senha autenticada | Não existe `POST /v1/me/password` (nem equivalente). Quem está logado e quer trocar a senha usa o fluxo de recuperação. | Candidato a endpoint futuro: senha atual + senha nova, autenticado, encerrando as outras sessões. Até lá o app não oferece a ação no Perfil. |
| 2026-08-26 | Deep link de reset em warm start | O esquema `meuauto` já está no Manifest (`singleTop`) e no Info.plist. O Flutter encaminha o URI via `pushRouteInformation` no `onNewIntent`. | Não adicionar `app_links` até constatar que o mecanismo padrão falha no aparelho. |
| 2026-08-27 | Dado técnico por modelo não existe | A aplicabilidade automática vem só de `vehicles.fuel_type` — o que uma motorização **é**. Correia × corrente, intervalo de fabricante, fluido específico de câmbio: nada disso é derivável hoje, e nenhuma fonte confiável está integrada. A FIPE identifica o veículo; **não** é fonte de plano de manutenção. | O sistema pergunta em vez de inventar, e "não sei" é resposta gravada. Reabrir quando existir uma fonte de dado por modelo — aí `vehicle_profile_answers` vira o lugar de gravar `source: manufacturer` em vez de `user`. |
| 2026-08-27 | Só existe uma pergunta de perfil | `timing_drive` é a única em `internal/maintenance/profile.go`. Outras candidatas óbvias (tipo de câmbio, fluido de arrefecimento, freio a disco nas quatro rodas) não entraram porque não têm consequência clara no catálogo atual. | Uma pergunta nova é um elemento a mais na lista em Go. Só vale acrescentar quando a resposta **decidir** um item do catálogo — pergunta sem consequência é fricção. |
| 2026-08-27 | `origin` tem seis valores e o servidor escreve dois | `manufacturer`, `manual`, `admin` e `external_provider` existem no CHECK e no contrato; nada os grava. | Deliberado: a coluna responde "quem disse isso?" e ampliá-la agora custou uma migration, ampliá-la depois custaria uma migration **e** um app antigo que não conhece os valores. O `parseEnum` do app já cai em `desconhecido`. |
| 2026-08-27 | Híbrido plug-in não tem valor próprio em `fuel_type` | `hibrido` cobre híbrido e híbrido plug-in. Os componentes são os mesmos (motor a combustão + bateria de tração), então a aplicabilidade não muda. | Não inventar um valor novo sem necessidade de produto. Se algum dia um item existir só em PHEV, aí sim. |
| 2026-08-27 | Item marcado `not_applicable` continua acessível por id | `PlanDetailScreen` lê `maintenancePlansProvider`, que exclui esses planos, e mostra "Este plano não está mais ativo." Nenhuma rota do app leva a um deles hoje (a tela de perfil não navega para o detalhe, e um item inaplicável nunca vira alerta). | Se algum dia um deep link levar a um, a frase fica enganosa. Trocar por "Seu carro não usa este item" quando isso acontecer. |

