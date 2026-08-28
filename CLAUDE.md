# Meu Auto — App (Flutter)

## What this repo is

The **Flutter mobile app** for Meu Auto, a vehicle upkeep tracker for individual car owners in Brazil.

Product truth (users, purpose, positioning, scope, open decisions) lives in [`PRODUCT.md`](./PRODUCT.md) in this repo. Read it before making product or design decisions — do not re-derive them from code.

## Two separate repositories

Meu Auto is **not a monorepo**. It is split into two independent git repositories, cloned side by side:

```
meu-auto/
├── meu-auto-app/       ← this repo — Flutter app (iOS + Android)
└── meu-auto-backend/   ← separate repo — Go API + PostgreSQL
```

Consequences to respect:

- The two repos version and deploy **independently**. Never assume a change here lands together with a backend change — API changes need a compatibility story, not a coordinated commit.
- There is no shared build, no shared lockfile, no cross-repo import. Anything both sides need (API contract, shared types) must be duplicated deliberately or generated from a spec — decide which before the first endpoint is written.
- `PRODUCT.md` lives **only in this repo** and is the single source of product truth for both halves. The backend repo points here rather than keeping a copy.
- The parent `meu-auto/` folder is just a convenience directory. It is not a repo and nothing is tracked there.

## Stack

- **Flutter** — one codebase, shipped to both the App Store and Play Store.
- Backend is **Go + PostgreSQL** (separate repo, see above).

## Platform and design language

Meu Auto uses **one shared design language on both iOS and Android** — a deliberate choice, not an oversight. Do not introduce per-OS design branching (Cupertino widgets on iOS, Material on Android). Material is the structural baseline.

Platform **mechanics** still differ and must be handled:

- Safe areas, notch and Dynamic Island insets on iOS.
- The interactive edge-swipe back gesture on iOS.
- System permission and notification prompts, which follow each OS.
- App Store and Play Store review requirements.

Rule of thumb: **look** follows Meu Auto, **plumbing** follows the phone.

## Language conventions

- **All user-facing strings are Brazilian Portuguese (pt-BR).** No other locale is in scope. Currency is BRL (`R$`), distance in kilometres, dates in Brazilian format, timezone `America/Sao_Paulo`.
- **Code, identifiers and comments are in English** — except domain terms below.
- **Brazilian vehicle domain terms stay in Portuguese in code**, because translating them loses the legal meaning: `ipva`, `licenciamento`, `crlv`, `revisao`, `seguro`, `multa`, `abastecimento`. Write `nextRevisaoDate`, not `nextInspectionDate`.

These are conventions, not laws from the user — say so if you want to change one.

## State of the repo

**The MVP is feature-complete and audited four times.** Against the local API the app signs in and registers, manages vehicles and switches between them, shows the dashboard and its alerts, records and corrects mileage, keeps maintenance plans and service records, tracks IPVA, licenciamento and seguro (`lib/features/obligation`), logs abastecimentos and shows derived consumption (`lib/features/abastecimento`), shows a unified timeline and a costs view, runs the `calibrar` onboarding, and lets someone edit their profile or delete the account. Vehicle registration picks brand, model and year from the FIPE catalogue instead of asking for four free-text fields.

**Visual identity** lives in [`docs/IDENTIDADE-VISUAL.md`](./docs/IDENTIDADE-VISUAL.md). The four PNGs in `assets/icon/` are processed art, not sketches: do not resize, recolour, or “optimize” the alpha. Regenerating native resources is two commands, recorded there.

What exists, and is the pattern to follow rather than re-invent:

- `lib/core/config` — `AppConfig`, compile-time only, fed by `--dart-define-from-file=dart_defines/development.json`. **No API URL may appear anywhere else.**
- `lib/core/domain` — `CivilDate`, `Money`, formatters, `phrases.dart`, `parseEnum`, `CursorPage`, `newClientId`. **Pure Dart: a `package:flutter` import here is a test failure, on purpose** (`test/core/domain/no_flutter_import_test.dart`).
- `lib/core/network` — one `ApiClient` (Dio), one `ApiFailure`, `ApiPaths`. No `DioException` escapes this folder; everything surfaces as `ApiFailure`.
- `lib/core/session` — `TokenStorage` (secure storage + in-memory cache), `SessionManager`, `AuthInterceptor`.
- `lib/core/router` — `go_router` with `authRedirect`, a pure function of `AuthStatus` + location.
- `lib/core/theme` + `lib/shared/widgets` — tokens and the base widgets. `AppStatus.colorsFor` is the **single** place that maps a domain state to a colour; a second one is how the screens start disagreeing.
- `lib/core/application` — `PagedFamilyController` and `shouldLoadMore`, the base for every cursor-paginated list.
- `lib/features/auth` — the reference feature. Copy its `domain/data/application/presentation` shape.
- `lib/features/catalog` — the vehicle catalogue (brand → model → year), read-only. The app never writes to it.
- `lib/features/obligation` — IPVA, licenciamento and seguro. Status arrives computed; the app never derives a due date.
- `lib/features/abastecimento` — fills and full-tank consumption. The number comes from the server; unknown `ConsumptionStatus` is `desconhecido`, never `ok`.

**Architecture decisions already made. Do not relitigate them mid-feature:**

- Riverpod **without** code generation; `go_router`; Dio; models written by hand.
- **No `build_runner`, no `freezed`, no `json_serializable`, no `get_it`, no OpenAPI client generator.** The backend's `SPEC.md` D-03 records the same decision.
- Dependencies are exactly: `flutter_localizations`, `flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage`, `shared_preferences`, `intl`, `uuid`, `url_launcher`. Adding another is a decision, not a detail.
- `intl` is **pinned by `flutter_localizations` from the SDK** (0.20.2). Bumping it past that breaks version solving.
- Riverpod 3.x and go_router 18.x are available and deliberately not taken until after the MVP ships. Sequencing, not neglect.

**The trap that already bit once:** the backend rotates refresh tokens and treats a re-presented token as theft, killing every session the user has. Two rules fall out of that, and both are covered by tests that must keep passing:

- Refresh is **single-flight** — `test/core/session/session_refresh_test.dart` fails if five simultaneous 401s produce more than one `/auth/refresh`.
- A refresh that **never reached the server** (dropped signal, timeout, 5xx) must **keep** the stored token, because it was never spent. Only an answer from the server — a 4xx, or a 2xx we could not read — ends the session. See `test/core/session/session_offline_refresh_test.dart`.

**Not every car has every part, and the app never decides which.** An electric vehicle gets no oil-change plan, a chain-driven car gets no timing belt, and neither is a card that is hidden or greyed out — `GET /maintenance-plans` simply does not return them. Five consequences, and each one is deliberate:

- **`maintenancePlansProvider` is the personalised list.** No screen built on it can show an item the vehicle does not have. `maintenancePlansWithHiddenProvider` is the opt-in, and exactly two places use it: the profile screen, which offers to undo one, and `PlanCreateSheet`, which must not re-offer an item already ruled out.
- **`strategy` chooses words, never state.** A tyre that has run its suggested distance is `vencido` on the wire and reads as "vale checar" on screen, because `condition_based` is not a deadline. `plan_copy.dart` is the one place that translation lives.
- **"Não sei" is a write, not a skip.** `PlanUpdate.history` records it so the question stops coming back, and it deliberately creates no `maintenance_record` — a record asserts a date and a mileage that the person does not have. "Não sei" and "nunca foi feito" are different answers and must never read the same.
- **The onboarding asks nothing the server did not write.** `calibrar_questions.dart` used to hold a list of technical slugs and a `switch` writing a pt-BR question for each — which is precisely how every car, including the ones with no engine, ended up being asked about its timing belt. Both the wording and the ranking now arrive on the plan (`history_question`, `history_priority`). **Do not put a slug back in that file.**
- **The profile is server-owned.** `lib/features/maintenance/domain/maintenance_profile.dart` renders questions the server wrote and posts back a value it offered. Which catalogue items an answer turns on and off is never expressed here.

**The rule that shapes every screen:** the app does not compute domain state. `status`, `due_on`, `due_at_km`, `remaining_days`, `remaining_km`, `warranty_until` all arrive computed by the server. The only logic here is presentation. Every `DateTime.now()` left in `lib/features` is a date-picker bound, never a comparison that decides a status — keep it that way. `.cursor/rules/meu-auto.mdc` carries the full list; `docs/API.md` is the contract map.

**Secrets and logging.** `LoggingInterceptor` is added to Dio **only under `kDebugMode`**, and even then it redacts the `Authorization` header and any `password`, `access_token`, `refresh_token` or `token` key, at any depth. `SessionTokens.toString` does not print the tokens. Tests assert all of this — do not "improve" the logger by printing the raw body.

**Cleartext HTTP is a development affordance and is not in the release build.** `network_security_config.xml` is attached by the **debug and profile** manifests only; the release manifest references no config, so Android denies cleartext outright. On iOS the `Info.plist` carries `NSAllowsLocalNetworking` and **must never carry `NSAllowsArbitraryLoads`**.

**[`docs/PADROES.md`](./docs/PADROES.md) is the shape of a feature** — the four layers, `fromWire` on every enum, `listOf`/`pageOf` for collection responses, `ApiFormErrors` for 422, and the rule for what to invalidate after a write. Read it before adding a feature; it was consolidated from the three that already existed, so following it costs nothing and diverging from it needs a reason.

**Read screens follow one shape, set by `lib/features/dashboard`:** a repository, a `FutureProvider.family` keyed by vehicle id, a `ConsumerWidget` that owns loading/error/content, and a **pure** content widget that takes the model and no `ref`. Keeping the content widget provider-free is what lets its copy be tested without a `ProviderScope` — see `test/features/dashboard/presentation/`. Anything that writes invalidates `dashboardProvider(vehicleId)`.

**Writes follow `lib/features/odometer`.** A write patches what the response already gave it, then invalidates only what actually moved: the odometer response carries the updated vehicle, so `vehiclesProvider.applyUpdated` takes it without a round trip, and `dashboardProvider(vehicleId)` is invalidated because every distance-based due date shifted. Do not refetch what the server just handed you, and do not invalidate the world.

**The vehicle catalogue assists the form; it never owns it.** `VehicleCatalogSheet` fills brand, model, year and fuel, and typing all four by hand stays a first-class path that is never hidden — the catalogue may not have the car, and the source may be down. Four things follow, and each is deliberate:

- **The app sends one id.** `catalog_model_year_id` alone; the server derives the brand and model links from it, so a model belonging to another brand is not expressible from here. Do not add the other two to a request body.
- **The text fields are a snapshot, not a mirror.** The picker copies into them and they stay editable. Someone who picks a Prius and then corrects the version keeps their correction, and a supplier renaming its own description never rewrites a registered vehicle.
- **`fipe_price: null` is a documented `200`, not an error.** With the source unreachable the rest of the detail still arrives and registration still works; the card says the value is unavailable and does not read as a failure. Never turn that into an error state.
- **`fuel_type` from the catalogue goes straight into the write.** The server already translated the source's word (`Híbrido` → `hibrido`); `fuel_label` is display only. The app owns no translation table and must not grow one.

**`showOdometerRollbackDialog` is shared, and stays shared.** A maintenance record carries a mileage and hits the same `odometer_rollback` rule, so the maintenance form reuses that dialog rather than writing a second one. Two things it must keep doing: never render `details.hint` (it says `reenvie com source "correction"` — an instruction for the client, not words for a person), and never resend as a correction unless someone tapped the button. Both are covered by tests.

**Paginated lists extend `PagedFamilyController`** (`lib/core/application`). A subclass writes `fetchPage` and nothing else; the cursor is private and never leaves it, because the contract says the cursor is opaque. Failing to load page four must never wipe pages one to three — that behaviour is covered by tests and is the reason the class exists. The scroll listener that triggers the next page is `shouldLoadMore`, one function with one threshold — three screens each had their own copy of it.

**Money and mileage are typed through a mask, never as raw integers.** `AppMoneyField` and `AppKmField` (`lib/shared/widgets/app_number_field.dart`) write `R$ 420,00` and `98.450` into the field as the digits arrive; `centsFromMoneyField` and `kmFromField` read the integer back out. The field used to say "digite em centavos" and take `42000` — someone typing `420` recorded R$ 4,20 and never found out. Do not add a numeric field for money or distance that skips them, and do not parse one with a bare `int.tryParse`: the text has separators in it now.

**Three things exist once because they existed three or four times first.** Reach for them instead of writing a fourth copy:

- `newClientId()` (`lib/core/domain/client_id.dart`) — the UUIDv7 a POST sends so a retry is not a second row. Repositories still take an injectable `newId` and default to this.
- `pickPastDate()` (`lib/shared/widgets/app_date_picker.dart`) — every "when did this happen" field. **The future is not selectable**, because the server rejects it and offering a day that comes back as a 422 is worse than not offering it.
- `shouldLoadMore()` (`lib/core/application/load_more_scroll.dart`) — the prefetch threshold for paginated lists.
- `confirmAction()` (`lib/shared/widgets/app_confirm.dart`) — the confirmation dialog, which seven screens had each written out. The confirm button says the verb, never "Confirmar", and `destructive: true` is the only thing that paints it red. The odometer rollback dialog stays separate: it renders server-supplied detail and has its own rules.
- `AppDateField` (`lib/shared/widgets/app_date_picker.dart`) — the "when did this happen" field. It is a form field, not a text row with a button beside it.

**`AppEmptyState` and `AppErrorState` scroll, and that is load-bearing.** They wrap `AppCenteredScroll`, which uses `AlwaysScrollableScrollPhysics` even when the content fits, because `RefreshIndicator` needs a scrollable child — without it, pull-to-refresh silently did nothing on the empty and error screens. `AppCenteredScroll` skips its own scroll view when it is handed an unbounded height, since that means an ancestor already scrolls.

**`ApiPaths` is the app's declared API surface, not a copy of the contract.** A route the app does not call does not get a builder there — `test/contract/openapi_paths_test.dart` reads that file and checks every path against the backend's `openapi.yaml`, so a builder nobody calls widens what is being asserted for nothing.

**The design gallery lives under `test/`, not `lib/`.** `test/support/design_gallery.dart` renders every token and base widget on one page, and `test/widget_test.dart` pumps it in both themes — which catches an overflow before a screen does. It sat in `lib/shared/widgets/dev/` for a while even though no route reached it; a widget only a test builds is a test fixture.

**A build warning that is not a bug:** `flutter build apk --release` prints `Expected to find fonts for (packages/cupertino_icons/CupertinoIcons, MaterialIcons)`. `cupertino_icons` was deliberately dropped from the dependencies, but Material widgets the app does use (`TextField`, `AlertDialog`, `RefreshIndicator`) import Cupertino sources that hold `const CupertinoIcons` values, so the icon tree-shaker sees them. Nothing in `lib/` builds a Cupertino widget, so no glyph is ever drawn. Do not add the package back to silence it.


## Things not to invent

There are **no** customers, testimonials, benchmarks, user counts, pricing, partnerships, brand assets, logo, palette or typeface. `PRODUCT.md` records this explicitly. Where a screen needs content or proof, ask for it or mark it clearly as placeholder — never fabricate it.

Several product facts are **deliberately open** (motorcycles, fines tracking, auth method, notifications, monetization). They are listed in `PRODUCT.md`. Raise them when work touches them; do not quietly pick an answer.
