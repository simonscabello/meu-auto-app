# Meu Auto — app

App Flutter para quem tem carro e quer parar de descobrir tarde demais que a
revisão passou, que o óleo venceu ou que o IPVA está próximo. O dono cadastra o
veículo, informa a quilometragem de vez em quando e o app responde o que está em
dia, o que está perto e o que já passou.

Duas metades independentes, em repositórios separados e lado a lado:

```
meu-auto/
├── meu-auto-app/       ← este repositório — Flutter (Android + iOS)
└── meu-auto-backend/   ← Go + PostgreSQL
```

**A regra que explica o resto do código:** o app não calcula estado de domínio.
`status`, `due_on`, `due_at_km`, `remaining_days`, `remaining_km` e
`warranty_until` chegam prontos do servidor. Aqui só se apresenta. Foi assim de
propósito — duas implementações da mesma regra acabam discordando, e a que o
dono vê passa a depender de qual tela ele abriu.

Verdade de produto (para quem é, o que está fora de escopo, o que está em
aberto) fica em [`PRODUCT.md`](./PRODUCT.md).

## Rodando em desenvolvimento

Precisa da API do repositório irmão no ar. O caminho completo — subir o
Postgres, subir a API, emulador, aparelho físico, deep link de senha — está em
[`docs/RODANDO.md`](./docs/RODANDO.md). O resumo:

```bash
flutter pub get
flutter run --dart-define-from-file=dart_defines/development.json
```

`dart_defines/development.json` aponta para `http://10.0.2.2:8080`, que é como o
emulador Android alcança o `localhost` da máquina. **A URL da API não aparece em
nenhum outro lugar do código** — quem precisa dela lê `AppConfig`.

## Verificação

```bash
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed .
```

`flutter test` inclui `test/contract/openapi_paths_test.dart`, que abre o
`openapi.yaml` do backend e falha se o app referenciar uma rota que não existe no
contrato. Ele é pulado (não falha) quando `../meu-auto-backend` não está clonado.

## Build

```bash
flutter build apk --release --dart-define-from-file=dart_defines/production.json
flutter build appbundle --release --dart-define-from-file=dart_defines/production.json
```

Sem `android/key.properties` o release sai assinado com a chave de debug:
instala no seu aparelho, não sobe para a Play. Como gerar e configurar a chave
de assinatura está em [`docs/RODANDO.md`](./docs/RODANDO.md), assim como o
`flutter build ipa` — que **exige macOS** e não roda em Windows.

## Documentação

| Arquivo | O que responde |
| --- | --- |
| [`docs/API.md`](./docs/API.md) | O contrato, endpoint por endpoint: o que o app manda e o que recebe. |
| [`docs/PADROES.md`](./docs/PADROES.md) | A forma de uma feature — as quatro camadas, `fromWire`, `ApiFormErrors`, o que invalidar depois de escrever. Leia antes de acrescentar tela. |
| [`docs/RODANDO.md`](./docs/RODANDO.md) | Como rodar, como buildar, como assinar, o que depende de Mac. |
| [`docs/DECISOES-EM-ABERTO.md`](./docs/DECISOES-EM-ABERTO.md) | O que ficou pendente, o que decidir e quem decide — incluindo o que precisa ir para o repositório do backend. |
| [`CLAUDE.md`](./CLAUDE.md) | Arquitetura estabelecida e as armadilhas que já morderam. |
| [`PRODUCT.md`](./PRODUCT.md) | Produto. Não re-derive isso do código. |

## O que ainda não existe

Ícone e splash próprios: **não há arte**. O app usa o ícone padrão do Flutter até
que exista um logo — inventar um é explicitamente proibido
(`CLAUDE.md`, "Things not to invent"). IPVA, licenciamento e seguro têm rotas no
servidor mas ainda não têm tela; a aba Cuidados diz isso em vez de fingir.
