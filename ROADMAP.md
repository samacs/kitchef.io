# Kitchef — Roadmap

This is the honest, phase-by-phase map of what's shipped and what's next. Use it as a running source of truth: as each item lands, strike it through with `~~…~~` and check the box. New work lands on the next open phase.

Conventions:
- `[x] ~~item~~` — done and shipping in `develop`
- `[ ] item` — pending
- `[~] item` — in progress (at most one at a time per phase)
- Sub-bullets are design / acceptance notes, not separate items.

---

## Phase 1 — Foundations (shipped)

- [x] ~~Rails 8 skeleton with Hotwire + Propshaft + Importmap~~
- [x] ~~Design system: bone background, deep-green accent, Instrument Serif + Inter + JetBrains Mono~~
- [x] ~~Dark mode scaffolding with pre-paint boot to avoid FOUC~~
- [x] ~~Rails 8 native auth (sessions, sign-in / sign-up / reset password)~~
- [x] ~~Routing constraints (`UserConstraint`, `AdminConstraint`) for root + admin dispatch~~
- [x] ~~Panel layout (sidebar + top bar + main) + marketing layout~~
- [x] ~~Multi-tenancy via `Account` + `Current.account`, `has_prefixed_id`, soft delete, paper trail~~
- [x] ~~es-MX as the only locale; `$` MXN, `tú` address, real Mexican names in seeds~~
- [x] ~~Reserved-slug guard + `bin/check_reserved_slugs` CI hook~~

---

## Phase 2A — Recipes (shipped)

- [x] ~~Recipe model with saleable / internal + yield + category + friendly slug~~
- [x] ~~CRUD form with photo upload (single image, `has_many_attached :photos`)~~
- [x] ~~Recipe grid grouped by category with publish-state badge~~
- [x] ~~Publish toggle on the recipe form (gated by photo attachment)~~
- [x] ~~One-click "Publicar" / "Ocultar" action on each card~~
- [x] ~~Bulk "Publicar todas" banner when drafts-with-photos exist~~
- [x] ~~Photo-required-to-publish validation (`will_save_change_to_is_published?` narrowed)~~

---

## Phase 2B — Clients (shipped)

- [x] ~~Client CRUD with right-side drawer form~~
- [x] ~~Phone normalization (`Phone::NormalizeMx`), E.164 storage, Mexican format validation~~
- [x] ~~Client search (case-insensitive name/phone/email)~~
- [x] ~~Autosave-on-blur drawer form with Guardando/Guardado status pill~~
- [x] ~~Autocomplete client picker on order form, keyboard-navigable (arrows + Enter fills shipping)~~
- [x] ~~`Client.find_or_create_by_phone!` with race-safe partial unique index~~

---

## Phase 2C — Orders (operator side, shipped)

- [x] ~~Order model with AASM lifecycle (placed → confirmed → in_production → ready → en_route → delivered → paid)~~
- [x] ~~Kanban board with per-column scroll, drag-reorder, real-time broadcast~~
- [x] ~~Order drawer form: customer picker, line items, delivery date/window, notes~~
- [x] ~~Cancellation flow with required reason code + optional note~~
- [x] ~~Duplicate-from-canceled shortcut~~
- [x] ~~Geocoding for delivery orders via `GeocodeOrderJob` (Google + cooldown on failure)~~
- [x] ~~Delivery window + day stored as integer minutes-from-midnight (timezone-safe)~~
- [x] ~~Rate-limited order-ID enumeration guard via rack-attack~~

---

## Phase 3 — Public Storefront + Kitchen Config (shipped)

- [x] ~~Public storefront at `kitchef.mx/:slug` — hero, menu grouped by category, info strip, cart~~
- [x] ~~`Accounts::Branding` with primary + secondary palette (10 curated palettes, all AA-contrast in both themes)~~
- [x] ~~Palette-neutral dark-mode chrome on public pages (distinct from operator-app warm chrome)~~
- [x] ~~Customer-controlled theme cycle (auto → light → dark, persisted per-slug in localStorage)~~
- [x] ~~Guest checkout: name + phone + address only; no registration~~
- [x] ~~Cart via `storefront_cart_controller` with sessionStorage persistence~~
- [x] ~~Checkout form with collapsible "Personalizar" notes accordion~~
- [x] ~~`Storefronts::PlaceOrder` command → `Orders::Place`, phone-based client dedup, `source: :storefront`~~
- [x] ~~Per-order confirmation page with customer-facing status timeline~~
- [x] ~~Real-time status broadcast via `broadcasts_refreshes_to [order, :status]`~~
- [x] ~~Kitchen config page at `/account/edit` with live storefront preview~~
- [x] ~~Inline autosave with Guardando/Guardado/Error pill (via `fetch()` + `X-CSRF-Token` header, multipart-safe)~~
- [x] ~~Flexible fulfillment: `delivery` + `pickup` (shipping intentionally deferred)~~
- [x] ~~Accepting-orders weekly schedule + chip on hero~~
- [x] ~~Pickup reminder scan job (`PickupReminderScanJob`, cron every 15min)~~
- [x] ~~Operator-aware empty state: "Tienes N platillos en borrador" nudge when the owner visits her own storefront with zero published~~
- [x] ~~Smooth-scroll "Ver menú" CTA (no URL fragment pollution)~~
- [x] ~~Dismissible flash messages (hover-pause, X close, 5s auto-dismiss)~~
- [x] ~~`Ui::Contrast` WCAG helper (Ruby + JS) + palette audit (all 10 palettes pass AA body)~~
- [x] ~~Seed photos via Unsplash CDN (accounts' cover/logo + 14 saleable recipes)~~

### Phase 3 deferred (small but worth naming)

- [x] ~~Recipe autosave on `/recipes/:id/edit` (form-autosave + `head :no_content` + photo-reupload guard via `form-autosave:success` event)~~ — shipped with Phase 4
- [ ] Shipping fulfillment type (paquetería/couriers) — deferred with the enum intentionally minimal
- [ ] Live palette hex from `Ui::Contrast` instead of the pre-stored `ink` field — optional optimization
- [ ] Hide-Kitchef-branding enforcement wired to Pro subscription (currently always visible)

---

## Phase 4 — Order confirmation, notifications, comms (shipped)

The storefront can *accept* an order and both sides now *know*: operator gets a live bell + inbox, customer gets a confirmation email with a self-confirm link, and payment is a property rather than a terminal state.

- [x] ~~Debounce-on-type autosave (600ms) as the canonical pattern on `/account/edit` and `/recipes/:id/edit`~~
- [x] ~~Recipe autosave (moved from Phase 3 deferred) — persisted-only, `head :no_content`, photo-reupload guard via `reset_files_on_save_controller`~~
- [x] ~~Operator notification bell when a new storefront order lands~~
  - [x] ~~Noticed event `StorefrontOrderPlacedNotification` targeted at the account owner~~
  - [x] ~~Delivery to database + ActionCable, per-user Turbo Stream morphs the top-bar bell badge live~~
  - [x] ~~`/notifications` inbox with Confirmar / Ver pedido / Marcar leída + "Marcar todas como leídas" bulk action~~
  - [x] ~~Auto-sweep related notifications when the operator confirms an order~~
- [x] ~~Customer confirmation email~~
  - [x] ~~`StorefrontOrdersMailer#placed` with kitchen cover, items recap, WhatsApp CTA, status link~~
  - [x] ~~Dev: letter_opener at `/letter_opener`; Prod-ready via Resend~~
  - [x] ~~Skipped gracefully when the customer didn't enter an email~~
- [x] ~~WhatsApp deep-link on the confirmation page (prominent, full-width mobile, branded CTA, pre-filled message)~~
- [x] ~~"One-click confirm" from the operator notification inbox — stays on `/notifications` and updates the row inline~~
- [x] ~~Customer self-confirm via email — public `GET /:slug/orders/:id/confirm` (idempotent, prefixed_id is the URL secret)~~
- [x] ~~End-to-end smoke test — `bin/smoke_storefront_order` exercises Storefronts::PlaceOrder → notification → email → confirm (19 assertions)~~
- [x] ~~Checkout polish: empty-cart submit disabled, phone-required/email-optional, delivery-date `min`, time-format hint, inline validation errors~~
- [x] ~~Kitchen config: ordering-hours weekly grid editor with "Cerrado" toggle (no more JSON-via-console)~~
- [x] ~~Payment is now a property, not a state — removed `:paid` from AASM, added `mark_paid!` / `unmark_paid!`, payment chip on operator card + public page, morphs live via Turbo~~
- [x] ~~Kanban: removed the "Pagados" column; delivered is terminal; payment action available at every non-canceled state~~
- [x] ~~"Focus comment"-style flash: cards highlight + smooth-scroll when navigated via `#ord_xyz` fragment (from email links, notification clicks, or column transitions)~~
- [x] ~~Storefront cart clears on the confirmation page via `storefront-cart:clear` custom event~~
- [x] ~~Cart drawer + storefront-cart controller moved to `<body>` so "Carrito" works from every page~~
- [x] ~~Reveal component (Ver más / Ver menos) on menu cards + kitchen hero description; description limit doubled to 560 chars~~
- [x] ~~Branded checkout: `.kc-sf-input` / `.kc-sf-radio` pick up the per-kitchen palette on focus/check states~~
- [x] ~~Delivery address required iff `delivery_type: delivery` (server + JS toggle); pickup orders submit clean~~
- [x] ~~`Orders::Place` resolves both numeric and prefixed recipe IDs (fixes empty-items bug from storefront cart)~~
- [x] ~~StoreModel + fields_for fix: explicit object binding so `public_profile.tagline` / `description` populate correctly~~
- [x] ~~Storefront checkout form scope fix: `fields_for :order` instead of `f.fields_for :order` (was producing malformed `[order][…]` names)~~
- [x] ~~Client edit drawer: fixed "Content missing" by skipping the layout's drawer shell on turbo-frame requests (duplicate `id="drawer_content"` resolved)~~

### Phase 4 deferred (small but worth naming)

- [ ] WhatsApp confirmation message (phone-only orders) — requires Twilio WhatsApp Business setup + webhook controller; ships with Phase 6 or Phase 10
- [ ] Operator email lane on `StorefrontOrderPlacedNotification` — `notify_new_orders` flag exists on `Accounts::Settings`, wire the actual email when there's demand
- [ ] Full preferences UI for notification flags — stays console-toggleable until the list outgrows three
- [ ] Real headless-browser E2E (Capybara / Playwright) — when a test framework lands, the `bin/smoke_storefront_order` Ruby script becomes the first integration spec

---

## Phase 5 — Production planning & daily ops (next)

**Context.** After Phase 4, pedidos reliably land, confirm, and settle. The next pain is time-bounded: "Elena, it's Friday morning, what do I cook today? What do I need to buy? Who's getting what, and in what order?" The operator needs a single page that answers those three questions without scrolling a 40-card kanban.

Phase 5 is the week-view that sits *above* the kanban, plus the bits that turn a delivery day into a runnable list. It's the phase that makes Kitchef feel like operations software, not just a ticket printer.

**Why now (vs. later).** A single operator hits this pain around pedido #20/week. Two of the three alpha kitchens are already there; the third will be within a month. Shipping this before Phase 6 (payments) and Phase 7 (menu engineering) is the right call — menu engineering wants 60+ days of history, and payments can ride WhatsApp a little longer.

### Goals

1. Operator opens `/production` and sees today's cook list + today's handoffs + this week's shape, in one glance.
2. A print-friendly shopping list aggregates what needs to be bought this week, even in simple-mode (the ingredient-level precision ships with Phase 8 composable recipes).
3. Delivery slots get a proper editor: weekly grid, per-slot capacity, visible fill level.
4. A runner can bookmark a per-day URL with ordered deliveries + map links + one-tap "Entregado", without a login.

### Scope

#### Slice 1 — Daily focus view (M)

- [ ] `/production` (rename the stub) — a 7-day strip at the top (today-highlighted, scroll horizontally on mobile).
- [ ] Each day card: pedido count, quick-action chips ("3 por confirmar", "5 a cocinar", "2 entregas"), fills from that day's `delivery_date`.
- [ ] Tap a day → per-day panel below with two sections: **Cocinar hoy** (recipe × total qty summed across orders) and **Entregar hoy** (per-order handoff list with delivery window).
- [ ] "Iniciar producción para todos" bulk action on the cook list — fires `start_production!` on every confirmed order for that day.
- [ ] Print-friendly CSS for the daily panel (single-page, readable off paper).

#### Slice 2 — Weekly shopping list (S in simple-mode, rewrites in Phase 8)

- [ ] `/production/shopping-list` — aggregates the next 7 days of confirmed-but-not-ready orders.
- [ ] Simple-mode today: groups by *recipe name* with total qty + per-order notes roll-up ("Tamal verde — 12 porciones · 2 sin cilantro"). No ingredient math until Phase 8.
- [ ] Print-friendly layout (giant checkboxes, no sidebar).
- [ ] Subtle "Cuando termines tu recetario compuesto, esta lista baja al ingrediente" nudge — sets up Phase 8.

#### Slice 3 — Delivery-slot editor (M)

- [ ] Operator weekly slot grid at `/delivery-slots` — reuse the ordering-hours layout pattern (Lun–Dom × time pickers × "Cerrado" toggle).
- [ ] Per-slot capacity field (default unlimited, can set max N pedidos). No runtime throttling yet — just display.
- [ ] Fill indicator next to each slot: "Sáb 11:00–13:00 · 4 de 8 pedidos".
- [ ] Storefront checkout already reads slots via `DeliverySlot`; surface fill status in the customer's slot picker (greyed out when full, optional).

#### Slice 4 — Runner view (S)

- [ ] `/r/:token` (new top-level route) — read-only, per-day, token-signed URL.
  - Token encodes `account_id` + `delivery_date`; signed with `Rails.application.message_verifier(:runner)`.
  - Generated from a "Compartir ruta del día" button on the daily focus view.
- [ ] Lists the day's delivery orders in colonia-grouped, geocoded order (same data the kanban has today — no new optimizer).
- [ ] Each row: client name + address + window + line-items + "Ir en Maps" button (directions URL) + "Entregado" button.
- [ ] "Entregado" POSTs to a tokenized endpoint that fires `Orders::Transition.call(order:, event: :deliver)`; no session auth, idempotent on re-clicks.
- [ ] Add `r` to `Account::RESERVED_SLUGS` + `bin/check_reserved_slugs` to protect the runner mount.

#### Slice 5 — Bulk column actions (XS)

- [ ] Kanban column header dropdown with one action per column:
  - `placed` → "Confirmar todas"
  - `confirmed` → "Iniciar producción de todas"
  - `ready` → "Marcar todas en camino" (delivery only, pickup stays manual)
- [ ] All are confirmation-gated (`turbo_confirm`); each triggers the same AASM event per-card via a new `Orders::BulkTransition` command.

### Out (explicit deferrals)

- **Route optimization (TSP / multi-stop ordering).** Stay out until an operator actually complains — colonia grouping is good enough for ≤10 stops.
- **Ingredient-level shopping list.** Requires composable recipes (Phase 8); simple-mode groups-by-recipe holds the line until then.
- **DiDi / Rappi / Estafeta handoff.** Phase 10+; shipping enum is still deferred.
- **Capacity-based storefront throttling (hiding full slots in the customer picker).** Renders display-only in Slice 3; actual hide-when-full needs real demand data first.
- **Prep-timeline ("hacer masa domingo 5pm").** Nice idea from the old roadmap, but it's effectively a second scheduler on top of AASM — skip until we hear it asked for.

### Key decisions (to lock before building)

- **Runner view uses a signed URL token, not a JWT or short code.** Rails' `message_verifier` is already on-disk, rotates per Rails secret, and keeps the token opaque. Bookmarkable per-day URLs; yesterday's stops working tomorrow.
- **`/production` replaces the existing stub.** The route is already reserved; we just grow it into a real view.
- **No real-time on the runner view.** Polling or a manual refresh button is fine — the runner isn't staring at the page, and Action Cable wakeups on a mobile connection while driving is wasted battery.
- **Bulk transitions run in-process, not async.** Most accounts will bulk-transition ≤20 orders at a time; a background job just adds latency to the confirmation UI.

### Files to create / modify

**Controllers**
- `app/controllers/production_controller.rb` — replaces the stub; `#show` (daily focus) + `#shopping_list`.
- `app/controllers/runners_controller.rb` — tokenized, no-auth; `#show` + `#deliver`.
- `app/controllers/orders_controller.rb` — `bulk_transition` action per column.

**Commands / services**
- `app/commands/orders/bulk_transition.rb` — per-account bulk event fire, returns `{ succeeded: [...], failed: [...] }`.
- `app/services/production/daily_plan.rb` — groups orders by day + returns the cook/handoff structs.
- `app/services/production/weekly_shopping_list.rb` — simple-mode aggregator (stays there for Phase 8 to extend).
- `app/services/runner/token.rb` — `encode(account:, date:)` / `decode(token)`, both thin wrappers over `message_verifier`.

**Views / components**
- `app/views/production/show.html.erb`, `_day_card.html.erb`, `_cook_list.html.erb`, `_handoff_list.html.erb`
- `app/views/production/shopping_list.html.erb`
- `app/views/runners/show.html.erb`
- `app/views/delivery_slots/index.html.erb` — weekly grid, replaces the stub
- `app/components/production/day_card_component.{rb,html.erb}`
- `app/components/production/slot_row_component.{rb,html.erb}`

**Routes**
- `get "/production", to: "production#show"`
- `get "/production/shopping-list", to: "production#shopping_list"`
- `post "/orders/bulk/:event", to: "orders#bulk_transition"`
- `get "/r/:token", to: "runners#show", as: :runner` (top-level, added to `Account::RESERVED_SLUGS`)
- `post "/r/:token/orders/:id/deliver", to: "runners#deliver", as: :runner_deliver`

**Locales**
- `config/locales/es-MX/production.yml` — new file, operator-only keys
- Extend `panels.yml` with bulk-transition confirm copy

### Verification (from clean DB + seed)

1. **Daily view.** Seed creates ~30 orders across the week. Open `/production` → 7 day cards, today's card pre-expanded. Confirmed orders show in "Cocinar hoy"; delivery orders in "Entregar hoy" with the window.
2. **Cook list totals.** Pick two orders with the same recipe, different quantities → the cook list row sums them ("Tamal verde · 6 porciones").
3. **Bulk confirm.** With 5 `placed` orders, click the column dropdown → "Confirmar todas" → confirmation dialog → all 5 move to `confirmed` in one POST. Kanban morphs via the existing `broadcasts_refreshes_to`.
4. **Shopping list print.** `/production/shopping-list` → print preview renders a single page, recipe rows with qty, checkable.
5. **Delivery slots grid.** `/delivery-slots` → edit Saturday's 10–12 slot to max=8 → grid re-renders, fill indicator shows "4 de 8".
6. **Runner view.** From daily focus, tap "Compartir ruta del día" → copy the URL → open in incognito → loads without auth, shows ordered deliveries. Tap "Entregado" on one → POST succeeds, list updates, order moves to `delivered`.
7. **Token rotation.** Copy today's runner URL, change the system clock to tomorrow, reload → 404 or "Ruta expirada" (verifier rejects stale signatures).
8. **Lint / security.** `rubocop` clean, `brakeman -q` clean (token decoding is the only new mass-assignment surface; verifier output is safe).

### Effort estimate

| Slice | Rough effort | Unlocks |
|---|---|---|
| 1 — Daily focus view | M | The biggest UX payoff of the phase |
| 2 — Weekly shopping list | S | Ships even without composable recipes; real value lands in Phase 8 |
| 3 — Delivery-slot editor | M | Operators already ask for this |
| 4 — Runner view | S | Solo kitchens can hand off to a teenager with a phone |
| 5 — Bulk actions | XS | Quick win while touching the kanban |

Recommended merge order: **1 → 3 → 2 → 5 → 4**. The first three slices are independent; 5 and 4 ride on top of 1. Total phase: **~1 focused work-week**, assuming the smoke test stays green the whole way.

### Open-at-start questions

- **Runner token lifetime — per day or per delivery batch?** Per-day is simpler; the operator re-shares the next morning. Per-batch lets the operator split a day between two runners — defer until asked.
- **Should `/production` respect `Accounts::Settings.use_composable_recipes`?** Probably yes in Phase 8: the cook-list rows expand to prep sub-lists when a recipe is decomposed. In Phase 5, ignore the flag — everything renders the same way.
- **Printable shopping list — portrait or landscape?** Portrait; a phone-photographed paper list is how the pattern really works.

---

## Phase 6 — Payments

Mexican-specific, lots of integration surface. **Defer until we have 10+ operators asking.**

- [ ] Mercado Pago link generation (v1.5 target — simplest wedge)
- [ ] SPEI reference capture on Payment
- [ ] Stripe Checkout for anticipos (v1.6)
- [ ] Payment reconciliation dashboard
- [ ] Customer-facing "Pagar anticipo" button on the confirmation page (currently only shows "Te contacto por WhatsApp")

---

## Phase 7 — Menu engineering

Pro-tier analytics that pays for itself by helping the operator price correctly. **Requires ≥ 60 days of pedido history per operator to be useful.**

- [ ] Stars / plowhorses / puzzles / dogs matrix with plain-language labels
- [ ] Per-recipe monthly sales + margin trendlines
- [ ] Ingredient-impact analysis (which raw inputs drive the most cost across the operation)
- [ ] Reprice suggestions based on target margin + recent ingredient price moves
- [ ] Monthly email digest with one actionable insight

---

## Phase 8 — Composable recipes (advanced mode)

The technical quiet-superpower. **Design is locked (PRD/TRD §6); UI is the unknown.**

- [ ] Recipe decomposition form (component picker: ingredients OR other recipes)
- [ ] Cycle-detection at the form layer (surface the error before submit)
- [ ] Cost-tree visualization on the recipe detail page
- [ ] Transitive cost propagation when an ingredient price changes (`Recipes::DependencyGraph` already ships, needs UI tie-in)
- [ ] Onboarding flow for first-time decomposition (`Onboarding::Decomposition`, currently stubbed)
- [ ] Unit-conversion UX (kg ↔ g, l ↔ ml, strict cross-type)

---

## Phase 9 — Finance lite

- [ ] Weekly / monthly ingresos / costos / margen bruto
- [ ] Per-client lifetime value
- [ ] Excel export via `caxlsx`
- [ ] Deposit (anticipo) vs final-payment split views

---

## Phase 10 — Growth, retention, polish

- [ ] QR code generator for printed flyers (`rqrcode`)
- [ ] Daily operator digest email (`DailyOperatorDigestJob` — scaffold exists, needs content)
- [ ] Birthday reminders for clients (`BirthdayReminderJob`)
- [ ] Seasonal recipe templates (rosca de reyes, tamales de Navidad, pastel de XV años)
- [ ] Instagram post generator from recipe cards
- [ ] Referral program (*invita a una cocinera, ambas ganan un mes*)
- [ ] Custom domain on storefront (Pro-tier)
- [ ] SMS pickup/delivery reminders (Twilio — Pro-tier)
- [ ] Opt-in public directory of Kitchef kitchens (SEO play — NOT a marketplace, per PRD Non-Goals)

---

## Cross-cutting reminders (not phased — ongoing)

- [x] ~~Reserved-slug check in CI~~
- [x] ~~Rubocop Rails Omakase passes~~
- [x] ~~Brakeman reports only weak-confidence warnings (palette injection from frozen enum)~~
- [ ] Test suite — nothing yet. When it lands, `factory_bot` comes back; seeds keep using curated Mexican pools.
- [ ] Kamal deploy config + production environment
- [ ] Sentry + PostHog wiring (gems in Gemfile, not initialized)
- [ ] Sitemap generation + robots.txt (gem in Gemfile)
- [ ] Favicon + PWA manifest for the storefront

---

## Working order — my recommendation

1. ~~**Phase 4 first**~~ — shipped. The kitchen now hears every pedido and the customer gets a tracked confirmation with a one-tap self-confirm link. Payment was also refactored out of AASM — delivered is terminal, paid is a property.
2. **Phase 5 next (production planning)** — the first operator who gets more than 20 pedidos/week will ask for this by the second week. Two of three alpha kitchens are already there.
3. **Phase 8 (composable recipes)** turns Phase 5's simple-mode shopping list into an ingredient-level one. Worth building before Phase 6 if an operator asks for precise raw-input planning.
4. **Phase 7 (menu engineering)** only makes sense after ~60 days of history, which implies ~2 months of live users first.
5. **Phase 6 (payments)** comes after at least one kitchen has explicitly asked for it — until then, WhatsApp-for-payment + the payment-pending chip is enough. The WhatsApp-confirmation-message flow deferred from Phase 4 ships here.

Phases 9 and 10 are continuous; each ships a slice per quarter once the core loop is done.
