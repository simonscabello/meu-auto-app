# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

Meu Auto ships to **both** the Play Store and the App Store from one Flutter codebase wearing **one Meu Auto design language on both OSes** — the user explicitly chose a single shared design over per-OS adaptation. Material is therefore the structural baseline (recorded above as the governing platform), but iOS platform constraints still bind: safe areas and notch/Dynamic Island insets, the interactive edge-swipe back gesture, App Store review requirements, and iOS system permission and notification prompts. Design decisions follow the Meu Auto language; platform *mechanics* follow whichever phone the app is on.

## Stack

- **App:** Flutter (iOS + Android from one codebase)
- **Backend:** Go (golang)
- **Database:** PostgreSQL

Chosen by the user.

**Two separate repositories, not a monorepo.** `meu-auto-app/` (Flutter) and `meu-auto-backend/` (Go) are independent git repos cloned side by side under a plain `meu-auto/` convenience folder that is itself untracked. They version and deploy independently, share no build and no code, and a shipped mobile app cannot be force-updated — so API compatibility across versions is a real constraint, not a coordination detail. `PRODUCT.md` lives only in the app repo and serves both; each repo carries its own `CLAUDE.md`.

Both repos were empty at the time of writing — this is a greenfield build.

## Users

The primary user is an **individual car owner in Brazil** — a regular person with one or a few vehicles, not a professional. They are typically **on their phone, standing up, mid-errand**: at the gas station pump, at the shop counter while the mechanic writes up the order, in the parking garage after paying. Sessions are short and interruption-prone.

Their job is to stay on top of a vehicle they depend on but do not want to think about: what is coming due, what it has cost, and what has actually been done to it.

No second audience (mechanic, shop, fleet manager, dealership) is in scope. This is a single-sided, owner-facing product.

## Product Purpose

Meu Auto is a **vehicle upkeep tracker**. The owner logs services, fuel, expenses, mileage and documents against their vehicles, and the app turns that log into three things: upcoming deadlines, real running cost, and a complete service history.

Success is an owner who never gets caught out by a deadline, can answer "what does this car actually cost me" without a spreadsheet, and can hand over a credible record when they sell or when a shop's story does not match.

## Positioning

The product earns its place over a notes app or a spreadsheet on **three points at once**, all confirmed by the user — none of the three alone is the pitch:

1. **Never miss a deadline.** Proactive reminders for IPVA, licenciamento, insurance renewal and the next revisão. The app watches the dates so the owner does not have to.
2. **Know your true cost.** Fuel, maintenance, taxes and insurance resolved into what the vehicle actually costs — per period and per kilometre.
3. **A trustworthy history.** A complete, provable service record that raises resale value and settles disputes with a shop.

The mechanism a neighbouring product could not truthfully copy is the combination: a single log that simultaneously drives forward-looking alerts, backward-looking cost math, and a durable provable record. A reminders app does the first; a budgeting app does the second; a paper folder does the third.

Note: "effortless capture" was offered as an alternative positioning and **not** selected. Low friction remains a quality bar, not the product's claim.

## Operating Context

The domain is **Brazilian vehicle ownership**, and its real objects and rituals are part of the product, not a localization skin:

- **IPVA** — annual state vehicle tax, paid on a plate-based calendar.
- **Licenciamento** — annual vehicle licensing, with the **CRLV** as the resulting document.
- **Revisão** — scheduled manufacturer/shop service, driven by mileage or elapsed time.
- **Seguro** — insurance policy with a renewal date.
- **Multas** — traffic fines (mentioned as part of the domain; whether Meu Auto tracks them is undecided — see below).
- Fuelling (abastecimento) and odometer readings as the routine capture event.

Interface language is **Brazilian Portuguese (pt-BR) only**. Currency is BRL (R$), distances in kilometres, dates in Brazilian format. Other markets are not in scope, and the user did not ask for the build to be structured for later i18n.

## Capabilities and Constraints

Confirmed in scope:

- **Multiple vehicles per account**, with switching between them.
- **Accounts and cloud sync** — login required, the server holds the data, the same account works across devices.
- **Receipt photos and documents** — attaching, storing and viewing images of receipts, CRLV, insurance policies.
- Logging of services, expenses, fuel and mileage against a vehicle.
- Deadline tracking and reminders for the dated obligations above.
- Cost reporting derived from the logged entries.

Confirmed out of scope:

- **Offline operation.** Offline capture with later sync was offered and deliberately not selected. The app assumes connectivity and the cloud is the source of truth. This is a live architectural constraint, not an oversight — but it is a real usage risk worth revisiting, because the parking-garage and roadside moments described above are exactly where signal fails.
- Any shop-, fleet- or marketplace-facing surface.

Explicitly undecided — record, do not invent:

- Whether motorcycles and other vehicle types are supported alongside cars.
- Whether multas (fines) are tracked in-app.
- Authentication method (email/password, social, phone).
- Notification delivery (push, email, in-app only) and how far in advance reminders fire.
- Monetization — free, paid, or freemium — and any account limits.
- Whether fuel logging computes consumption/efficiency, or only cost.
- Whether IPVA/licenciamento calendars are seeded from official data or entered by the owner.

## Brand Commitments

The name **Meu Auto** is the only established brand fact. There is no logo, wordmark, palette, typeface, tone-of-voice document or existing visual identity — nothing has been designed or built yet. Future work is free to establish these, and must not treat any of them as pre-existing.

## Evidence on Hand

**None.** Both repositories are empty. There are no customers, testimonials, case studies, benchmarks, screenshots, press mentions, pricing, real user data or brand assets. Nothing about traction, user counts, partnerships, or third-party data sources has been established.

Future work must not fabricate any of these. Where a surface needs proof or content, it must be requested from the user or clearly marked as placeholder.

## Product Principles

1. **Dates are the heartbeat.** The owner's most valuable question is "what is coming?" — surface it before they have to go looking, and let everything else arrange itself around it.
2. **One entry, three payoffs.** Every logged event must serve the deadline view, the cost math, and the permanent record at once. Capture that only feeds one of the three is capture the owner will abandon.
3. **The record must be defensible.** History is the product's asset at resale and in a dispute — completeness, dates, amounts and attached documents are load-bearing, not decoration.
4. **Brazilian vehicle reality is the domain model.** IPVA, licenciamento, CRLV and revisão are first-class objects with their own rules — not generic "reminders" with Portuguese labels.
5. **Built for a short, standing, one-handed session.** The user is mid-errand with a pump handle or a counter in front of them. Depth is welcome; requiring depth to do the routine thing is not.
6. **One Meu Auto on both phones.** A single design language carries the brand across iOS and Android; only platform mechanics differ.
