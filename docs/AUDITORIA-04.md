# Auditoria 04 — formulários, hierarquia e presença de produto

**27 de agosto de 2026.** Quarta passada, depois das três anteriores terem fechado estados, acessibilidade e copy de vazios. O que sobrou não era mais "falta um estado": era o modelo de dados aparecendo no formulário, o cadastro do primeiro carro pedindo onze campos sem hierarquia, e a tela de entrada sem nada que dissesse de que produto se trata.

Nenhum endpoint, payload ou regra de negócio mudou.

## Resultado

| Verificação | Antes | Depois |
| --- | --- | --- |
| `flutter analyze` | limpo | limpo |
| `flutter test` | 457 | 545 |
| `dart format` | limpo | limpo |
| Layout 360×640 | escalas 1,0 e 1,3 | escalas 1,0, 1,3 e **1,6**, nos dois temas |

---

## Crítico

### 1. Os campos de dinheiro pediam centavos

`Digite em centavos: 42000 vira R$ 420,00` aparecia em três lugares. Quem digitasse `420` registrava **R$ 4,20** e não percebia — o valor errado entrava no histórico e na conta de custos.

`MoneyInputFormatter` (`lib/shared/widgets/app_number_field.dart`) escreve `R$ 420,00` no próprio campo enquanto a pessoa digita. A convenção de preencher dos centavos para cima continua — é a da maquininha, e não tem separador decimal para errar — mas agora ela é **visível** em vez de explicada numa linha de ajuda.

O `int` continua sendo o que vai para o servidor: `centsFromMoneyField` lê os dígitos de volta. Um teste no formulário de manutenção fecha o círculo — digitar `42000`, ver `R$ 420,00`, e o POST levar `total_cost_cents: 42000`.

### 2. A quilometragem não era agrupada enquanto se digitava

`98450`, não `98.450`, em todos os campos de km. Conferir seis ou sete dígitos sem separador, de pé, é exatamente onde o erro custa um diálogo de rollback.

`KmInputFormatter` agora vale para o odômetro, o formulário e a edição de manutenção, o calibrar, o cadastro de veículo, o intervalo do plano e a garantia em km. Zero continua sendo uma leitura válida — carro entregue hoje — e por isso não é apagado como um valor vazio é.

### 3. O cadastro do primeiro veículo era uma parede de onze campos

Nada dizia o que era obrigatório. No backend só **marca e modelo** são: `requiredText` em `internal/vehicle/dto.go`. A quilometragem, que é de onde sai toda data de vencimento, era o décimo campo.

O formulário virou seções: **O carro**, **Quilometragem**, **Como você reconhece**, e o documento dobrado. Os nove campos opcionais dizem `(opcional)` — marcar nove como opcionais é mais curto e mais gentil que deixar nove parecerem dever de casa.

E quando a tabela FIPE preenche marca, modelo, ano e combustível, esses quatro **dobram** atrás de uma linha que diz o que tem dentro. Continuam editáveis a um toque — o snapshot é da pessoa e sempre foi —, mas param de ocupar a tela como trabalho a fazer.

A placa ganhou máscara: sete alfanuméricos, maiúsculas, sem pontuação. É a mesma normalização que o servidor faz antes de validar `ABC1234` ou `ABC1D23`, só que onde ainda dá para ver acontecendo — o hífen que se digita por hábito some em vez de sobreviver até um 422.

## Importante

### 4. O dashboard respondia na ordem errada

O odômetro liderava; "meu carro está bem?" vinha depois, num banner. Inverteu-se: a resposta vem primeiro, em `headlineSmall`, e o número é o fato de apoio. `Seu carro está em dia` virou **`Tudo em dia`**; `Vamos deixar seu carro em dia` virou **`Falta informar o histórico`**.

### 5. O detalhe do veículo era uma tabela de onze pares

Todos empilhados, todos com o mesmo peso. Virou: a quilometragem como cabeçalho — a mesma linguagem visual do dashboard —, depois **Ficha do carro** e **Documento** em linhas de duas colunas. Ano de fabricação e ano do modelo viraram uma linha (`2017/2018`): duas linhas para dois números que ninguém lê separado é enchimento.

O "Excluir" saiu de botão vermelho cheio, competindo com "Editar", para um botão de texto abaixo de uma régua — o mesmo tratamento que a exclusão de conta já tinha no perfil.

### 6. O login não tinha marca nenhuma

AppBar "Entrar" e dois campos. `AppWordmark` é tipografia, não desenho: `Meu` no neutro, `Auto` no teal da marca, um pouco mais fechado que texto corrido. Nenhum logo foi inventado — quando existir um, ele substitui esse widget e nada mais muda. A AppBar saiu: era uma barra dizendo "Entrar" acima de um botão dizendo "Entrar", e toda tela alcançável dali tem o próprio caminho de volta.

### 7. Placeholders ocupavam a melhor posição

"IPVA, licenciamento e seguro entram em breve" era um cartão com cabeçalho de seção **acima** de "Cuidados do dia a dia". Virou uma linha de nota no fim da lista. No Quick Add, três linhas desabilitadas viraram a mesma nota, e as ações vivas foram reordenadas por frequência — quilometragem, manutenção, veículo.

### 8. A data tinha dois desenhos

Três telas mostravam uma linha de texto com um botão "Mudar data" ao lado; o calibrar mostrava um campo de formulário. `AppDateField` é um campo: fica na forma, carrega rótulo e erro como os campos vizinhos, e abre `pickPastDate` em qualquer ponto.

### 9. Sete diálogos de confirmação escritos à mão

Concordavam na forma por sorte. `confirmAction` (`lib/shared/widgets/app_confirm.dart`) guarda as duas regras: o botão de confirmar **diz o verbo**, nunca "Confirmar"; e `destructive` é a única coisa que pinta de vermelho, para que desativar um plano não peça emprestada a cor que significa "isto sumiu".

O diálogo de rollback do odômetro continua separado — ele é outra coisa, e os testes que o protegem seguem passando.

### 10. Sucesso e falha chegavam na mesma caixa cinza

`showAppErrorSnackBar` usa as cores de erro, dura mais e é dispensável. `showAppSnackBar` ficou só para escrita que deu certo, e ganhou **um** toque tátil leve — o único do app. Nada vibra em falha: um buzz numa falha é castigo, não informação.

---

## Encontrado pela escala 1,6

Subir a matriz de layout para 1,6 achou um bug que 1,3 escondia: `AppEmptyState` e `AppErrorState` não rolavam. Duas consequências, as duas silenciosas:

- Em fonte de acessibilidade grande, o botão de ação caía para fora da tela sem nada para alcançá-lo.
- `RefreshIndicator` precisa de um filho rolável — então **puxar para atualizar não fazia nada** justamente nas telas onde alguém mais puxa: a vazia e a de erro.

`AppCenteredScroll` resolve as duas. Quando a altura chega sem limite — um cartão dentro de uma lista, a galeria de design — ele não adiciona um segundo scroll: aí quem rola é o ancestral.

---

## Componentes novos

| Arquivo | O que é |
| --- | --- |
| `app_number_field.dart` | `MoneyInputFormatter`, `KmInputFormatter`, `AppMoneyField`, `AppKmField`, `kmController` |
| `app_wordmark.dart` | A marca tipográfica, em dois tamanhos |
| `app_centered_scroll.dart` | Centraliza e rola quando para de caber |
| `AppDateField` (em `app_date_picker.dart`) | O campo "quando isso aconteceu" |
| `confirmAction` (em `app_confirm.dart`) | O diálogo de confirmação, um só |
| `VehicleDetailContent` | A ficha do veículo, pública e sem provider, como `DashboardContent` |

Nada foi criado para um uso único. `AppMetric`, que era usado uma vez, agora é usado duas — dashboard e ficha do veículo — e é o que faz as duas telas parecerem o mesmo produto.

## Cobertura acrescentada

- `test/shared/widgets/app_number_field_test.dart` — as duas máscaras, tecla a tecla, incluindo apagar até zerar e o teto de nove dígitos.
- `test/features/vehicle/presentation/vehicle_form_screen_test.dart` — a máscara de placa contra as duas expressões que o servidor usa.
- `test/core/domain/formatters_test.dart` — os leitores mascarado e cru.
- `maintenance_form_screen_test.dart` — o valor que a pessoa vê é o valor que o POST leva.
- `small_screen_test.dart` — escala 1,6, mais a ficha do veículo (nome longo, sete dígitos) e os três campos mascarados juntos.
- `app_theme_test.dart` — contraste do snackbar de erro e da marca sobre a superfície.

## Deliberadamente não feito

- **Paleta, tipografia, spacing e raio** não foram mexidos. Estavam corretos, tokenizados e cobertos por teste de contraste. Os dois valores de raio soltos que restavam (`circular(20)`, `circular(AppSpacing.s8)`) viraram tokens.
- **Onboarding de três telas.** O produto se explica pelo cadastro do carro; o calibrar já é o passo que ensina.
- **Ilustração de estado vazio**, biblioteca de animação, logo desenhado.

## Pendências reais

- **Passe visual em aparelho.** Esta sessão não tinha display: a API Go local subiu e respondeu `{"status":"ok"}`, mas o painel do navegador não compõe frames, então screenshot é impossível aqui. O que a suíte cobre é layout em 360×640 nas três escalas e nos dois temas. O passe com rede desligada num aparelho continua sendo o critério que só o dono do emulador fecha.
- **IPVA, licenciamento e seguro** continuam sem tela. A nota diz isso; agora no fim da lista.
- **Ícone e splash** continuam sem arte — `docs/DECISOES-EM-ABERTO.md`.
