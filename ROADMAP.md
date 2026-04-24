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

## Phase 5 — Production planning & daily ops (shipped)

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

- [x] ~~`/production` (rename the stub) — a 7-day strip at the top (today-highlighted, scroll horizontally on mobile).~~
- [x] ~~Each day card: pedido count, quick-action chips ("3 por confirmar", "5 a cocinar", "2 entregas"), fills from that day's `delivery_date`.~~
- [x] ~~Tap a day → per-day panel below with two sections: **Cocinar hoy** (recipe × total qty summed across orders) and **Entregar hoy** (per-order handoff list with delivery window).~~
- [x] ~~"Iniciar producción para todos" bulk action on the cook list — fires `start_production!` on every confirmed order for that day.~~
- [x] ~~Print-friendly CSS for the daily panel (single-page, readable off paper).~~

#### Slice 2 — Weekly shopping list (S in simple-mode, rewrites in Phase 7)

- [x] ~~`/production/shopping-list` — aggregates the next 7 days of confirmed-but-not-ready orders.~~
- [x] ~~Simple-mode today: groups by *recipe name* with total qty + per-order notes roll-up ("Tamal verde — 12 porciones · 2 sin cilantro"). No ingredient math until Phase 7.~~
- [x] ~~Print-friendly layout (giant checkboxes, no sidebar).~~
- [x] ~~Subtle "Cuando termines tu recetario compuesto, esta lista baja al ingrediente" nudge — sets up Phase 7.~~

#### Slice 3 — Delivery-slot editor (M)

- [x] ~~Operator weekly slot grid at `/delivery-slots` — reuse the ordering-hours layout pattern (Lun–Dom × time pickers × "Cerrado" toggle).~~ **(Retired in Phase 6 — replaced by the richer `/schedule` editor with weekly grid + exceptions + autosave.)**
- [x] ~~Per-slot capacity field (default unlimited, can set max N pedidos). No runtime throttling yet — just display.~~ (Dropped with DeliverySlot in Phase 6.)
- [x] ~~Fill indicator next to each slot: "Sáb 11:00–13:00 · 4 de 8 pedidos".~~ (Dropped with DeliverySlot in Phase 6.)
- [x] ~~Storefront checkout already reads slots via `DeliverySlot`; surface fill status in the customer's slot picker (greyed out when full, optional).~~ (Storefront now reads from `Schedule` + `Availability` via `Schedules::AvailableWindows`.)

#### Slice 4 — Runner view (S)

- [x] ~~`/r/:token` (new top-level route) — read-only, per-day, token-signed URL.~~
  - [x] ~~Token encodes `account_id` + `delivery_date`; signed with `Rails.application.message_verifier(:runner)`.~~
  - [x] ~~Generated from a "Compartir ruta del día" button on the daily focus view.~~
- [x] ~~Lists the day's delivery orders in colonia-grouped, geocoded order (same data the kanban has today — no new optimizer).~~
- [x] ~~Each row: client name + address + window + line-items + "Ir en Maps" button (directions URL) + "Entregado" button.~~
- [x] ~~"Entregado" POSTs to a tokenized endpoint that fires `Orders::Transition.call(order:, event: :deliver)`; no session auth, idempotent on re-clicks.~~
- [x] ~~Add `r` to `Account::RESERVED_SLUGS` + `bin/check_reserved_slugs` to protect the runner mount.~~

#### Slice 5 — Bulk column actions (XS)

- [x] ~~Kanban column header dropdown with one action per column:~~
  - [x] ~~`placed` → "Confirmar todas"~~
  - [x] ~~`confirmed` → "Iniciar producción de todas"~~
  - [x] ~~`ready` → "Marcar todas en camino" (delivery only, pickup stays manual)~~
- [x] ~~All are confirmation-gated (`turbo_confirm`); each triggers the same AASM event per-card via a new `Orders::BulkTransition` command.~~

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

## Phase 6 — Scheduling, confirmation, storefront UX (shipped)

**Context.** Phase 5 closed the operations loop. Phase 6 tightened the customer side: a real `Schedule` with weekly availability + date exceptions (Agendario-style), two-step email-verified confirmation, and a picker that actually respects the kitchen's operating mode.

- [x] ~~Email infrastructure: `no-reply@kitchef.mx` as canonical From; display-name = kitchen; `Reply-To` = owner; Resend wired for production; letter_opener_web wired for development; shared `layouts/mailer.{html,text}.erb` for every mail to reuse chrome.~~
- [x] ~~`Schedule` + `Availability` models (Agendario-adapted): one schedule per account via `after_create :ensure_schedule`; `Availability` uses `wday XOR date` at the DB level; `order_mode` enum (`advance` / `same_day` / `both`); `lead_time_minutes` (exposed as hours in the UI).~~
- [x] ~~`/schedule` editor: weekly grid with multiple slots per day + date-specific exceptions; each row autosaves per-field via a nested `Schedules::AvailabilitiesController` (POST/PATCH/DELETE returning Turbo Streams) — no accepts_nested_attributes fragility, no "Save" button.~~
- [x] ~~`Order#delivery_mode` enum (`scheduled` / `asap`) via new migration; storefront picker refactored to post a single `delivery_window_id`, server-side `Schedules::AvailableWindows.decode` re-validates on submit.~~
- [x] ~~Storefront delivery picker redesign: segmented "Para hoy / Para después" (only in `both` mode) + one-tap ASAP card + date-chip strip / time-chip grid for scheduled windows. Respects `lead_time_minutes`, honors per-date exceptions, surfaces "Hoy no estamos cocinando" when closed today.~~
- [x] ~~Two-step confirmation: email CTA lands on the order page with a signed `?t=…` review token; the confirm block + "Confirmar mi pedido" button only render when the token matches. Direct URL access (without the email) shows a "Revisa tu correo" nudge. `POST /:slug/orders/:id/confirm` re-validates the token server-side.~~
- [x] ~~Email now required at checkout (identity-verification gate); `Storefronts::PlaceOrder` rejects submissions without one.~~
- [x] ~~`Order#review_token` + `Order.decode_review_token` (7-day TTL, `message_verifier(:order_review)`).~~
- [x] ~~WhatsApp pre-filled message (both on the confirmation page and in the placed email) now includes the operator's kanban deep-link `orders_url(anchor: dom_id(order))` — one tap takes the operator to the matching card, `target_highlight_controller` flashes it.~~
- [x] ~~Dish detail page at `/:slug/platillos/:recipe_slug`: hero photo + kitchen strip + price + description + Add-to-cart + WhatsApp "Preguntar" + "Más de esta cocina" related-dishes strip (prefers other categories). Menu cards split into secondary "Ver" + primary "Agregar"; card image + title both link to the detail page.~~
- [x] ~~Kanban + handoff-list cards now surface the short pedido id (`#gPbkHnr9`) so two near-identical pedidos from the same client are distinguishable at a glance.~~
- [x] ~~Cleanup: removed `/delivery-slots` + `DeliverySlot` model + capacity/fill-level service (superseded by `/schedule` + `Availability`); removed `ordering_hours` JSON editor from `/account/edit` (replaced with a link to `/schedule`); `Storefronts::OrderingHours` rewritten to read from `Schedule`.~~

### Phase 6 deferred (small but worth naming)

- [ ] **Customer self-reschedule** — once confirmed, no way for the customer to move the window. WhatsApp conversation handles this today.
- [ ] **Holiday preset library** — exceptions are 100% operator-driven; no "Mexican holidays auto-seeded" feature.
- [ ] **Multiple schedules per account** — single-schedule is the v1. Revisit if an operator asks for different rules per branch / service.
- [ ] **Capacity on `Availability`** — the old `DeliverySlot.capacity` display-only signal was dropped on the migration; can come back as `Availability#capacity` if operators ask to see fill rates.
- [ ] **Twilio WhatsApp Business** — still wa.me deep-links only.

---

## Phase 7 — Composable recipes (shipped)

**Context.** The cost engine was already in the codebase — `Recipes::CostCalculator`, `Recipes::CycleDetector`, `Recipes::DependencyGraph`, `Recipes::UnitConverter`, and the polymorphic `RecipeComponent` join. Phase 7 turned them on for the operator: recipes can now be composed of ingredients AND other recipes, arbitrarily deep, with live cost + margin everywhere they matter.

- [x] ~~Real `/ingredients` CRUD (replaced the stub): name, category, unit, default cost, supplier notes, last-price-changed-at.~~
- [x] ~~Recipe decomposition form inside `/recipes/:id/edit`: components picker (ingredient OR other recipe), qty + unit, live cost preview.~~
- [x] ~~Cycle detection at the form layer — `Recipes::CycleDetector` runs in `RecipeComponent#before_save` + is surfaced pre-submit via the `usable_as_component_for` scope, so the picker never shows a choice that would cycle.~~
- [x] ~~Cost-tree visualization on the recipe detail page — nested expandable tree down to raw ingredients (`Recipes::CostTreeComponent`).~~
- [x] ~~Saleable vs. internal toggle — form exposes "esta receta se vende / es una base"; internal preparations (masa, salsas, bases) live out of the saleable menu and the `bases` category surfaces them on the index.~~
- [x] ~~Ingredient-price-change impact panel — on ingredient update, shows which recipes shift + their new costs; offers a one-tap "rescale menu prices to keep margin" action backed by `Recipes::DependencyGraph`.~~
- [x] ~~Onboarding flow for first-time decomposition — `Onboarding::Decomposition` is live; first successful decomposition flips `settings.use_composable_recipes` via `Onboarding::CompleteFirstDecomposition`.~~
- [x] ~~Unit-conversion UX — kg↔g, l↔ml via `Recipes::UnitConverter`; strict on cross-type (grams ↔ liters requires a density hint, intentionally out-of-scope).~~
- [x] ~~`Production::WeeklyShoppingList` respects the composable flag — when it's on, the list rolls up to ingredients; when off, it stays recipe-level (Phase 5 kept this seam on purpose).~~
- [x] ~~`OrderItem#unit_cost_cents` now snapshots the real composed cost at order time, not a hand-tuned dummy — makes Phase 8's margin numbers meaningful.~~

### Phase 7 deferred (small but worth naming)

- [ ] Yield tracking ("esta batch rinde 20 tamales; si pides 2, consume 2/20 del costo de la batch") — a whole second mental model on top of components. Moves into Phase 9.
- [ ] Nutritional info — low priority in this market.
- [ ] Recipe versioning / price history — only matters once we have months of purchase history; lands with Phase 9's purchase ledger.

---

## Phase 8 — Finance & menu performance (shipped)

**Context.** Phase 7 made recipe cost real (`OrderItem#unit_cost_cents` is a snapshot of the actual composed cost at order time, not a placeholder). Phase 8 turned that accumulated cost + sale data into the two surfaces an operator refreshes once a week: "¿cuánto gané esta semana?" and "¿qué platillos mueven mi negocio?". No new models — pure aggregation + presentation on top of `OrderItem` snapshots.

- [x] ~~`/reports/finance` (replaces the stub) — KPI triptych (this-window / previous-window / month-to-date), 8-week trend chart, day-by-day breakdown, CSV export.~~
- [x] ~~`Reports::Finance` query — one SQL round-trip (`SUM + GROUP BY delivery_date`), returns immutable `PeriodStats` + `DayStats` structs. Revenue + COGS + margin all read from `OrderItem` snapshots so historical pedidos reflect that quarter's prices, not today's.~~
- [x] ~~Five presets: `this_week`, `last_week`, `this_month`, `last_month`, `last_30_days`, plus custom `?from=&to=`.~~
- [x] ~~Week-over-week / month-over-month / period-over-period compare surfaced on the primary KPI card. Month-to-date always shown alongside for ambient context.~~
- [x] ~~Inline SVG trend chart (`Reports::TrendChartComponent`) — zero-KB client JS, renders identically on 4G phones; bypasses chartkick deliberately to avoid the Stimulus/Chart.js dance.~~
- [x] ~~Empty-state copy ("Apenas empiezas — vuelve después de tu primera semana de entregas") when the window has < 3 delivered pedidos; KPIs still render (zeros are factual), but the chart + day list step aside.~~
- [x] ~~`/reports/menu` — ranked lists, three buckets: **Tus estrellas** (top 3 by margin contribution), **Estables** (the middle), **Revisa estos** (idle platillos first, then bottom-of-pack by margin). Each row links to `/recipes/:slug` for the Phase 7 cost tree.~~
- [x] ~~`Reports::RecipePerformance` query — per-recipe units-sold, revenue, COGS, margin, `last_sold_on` so idle platillos can say "último pedido hace N días" even when it's outside the window.~~
- [x] ~~Dashboard weekly snapshot card (`Dashboards::WeeklySnapshotComponent`) at the top of `/` — revenue, pedidos, margen, week-over-week compare, links to `/reports/finance?range=this_week`. Muted when < 3 delivered pedidos this week so the operator doesn't see a hard zero.~~
- [x] ~~CSV export on both reports (`?format=csv`), BOM-prefixed for Excel on es-MX, filename encodes the window.~~
- [x] ~~Locale polish: `reports.finance.*`, `reports.menu_engineering.*`, `dashboard.weekly_snapshot.*` under `panels.yml`; new `weekday_long` / `short_day` / `short_day_compact` date formats.~~

### Phase 8 deferred (explicit, small)

- [ ] BCG 4-quadrant menu-engineering matrix (stars / plowhorses / puzzles / dogs) — needs ≥60 days + ≥20 distinct platillos per operator for the thresholds to settle. Revisit once two operators have that much history.
- [ ] Fixed cost tracking (rent, gas, packaging) — net margin inputs, not gross. Different mental model; lands with Phase 9's ledger.
- [ ] Per-client LTV / CAC / retention cohorts — needs ≥90 days of repeat pedidos.
- [ ] PDF export — CSV handles the contador use case.
- [ ] XLSX via `caxlsx` — gem is in the Gemfile but formatting + formulas is a rabbit hole; CSV is enough.
- [ ] SAT / CFDI / IVA breakouts — operator-facing report, not fiscal; Phase 11+.

---

## Phase 9 — Catálogos, proveedores y compras (next)

**Context.** Phase 7 gave us real recipe costs. Phase 8 turned those costs into revenue + margin numbers. The next honest question — "¿cuánto gasté *de verdad* esta semana?" — isn't a theoretical COGS from delivered pedidos; it's the actual grocery run. Today the shopping list at `/production/shopping-list` is read-only: it tells the operator what to buy, but doesn't remember what they bought, for how much, or from whom. This phase closes that loop.

Phase 9 is also the natural home for two smaller UX asks that have been sitting open: editable **categorías** (currently fixed Rails enums for ingredients + recipes) and first-class **proveedores** (currently a free-text field on `Ingredient`). Both set up the purchase ledger — categories let the operator organize purchases by section of the market run, suppliers let a single ingredient track per-provider prices.

**Why now.** Every feature past this point (fiscal exports, real net profit, reorder alerts, inventory depletion, Pro-tier price intelligence) needs a *purchase fact* to anchor on. Shipping any of them before the ledger lands means either backfilling data later or showing half-truths in the meantime.

**Why this is bigger than it looks.** "Mark as bought" on the shopping list sounds like a checkbox. In reality it's ledger-based inventory: a `Purchase` entity, per-supplier price history, and a decision about whether recipe costs update retroactively (they shouldn't — Phase 7's `OrderItem#unit_cost_cents` snapshot stays locked). We'll lock those decisions before writing code.

### Goals

1. Operator adds a new category (ingredient or recipe) inline without waiting for a deploy.
2. One ingredient tracks prices from multiple proveedores; the operator picks which one the cost engine uses.
3. Shopping list turns from a read-only view into a persistent ledger — marking a line "comprada" records the real qty, real price, and which proveedor.
4. `/reports/finance` grows a "Gastos reales" lane that sums actual `PurchaseItem` totals alongside the margin-from-snapshots already on the page.

### Scope

#### Slice 1 — Categorías editables (S)

- [ ] Promote `category` to a first-class `Category` model — `account_id`-scoped, `kind` enum (`ingredient` / `recipe`), soft-deletable, positioned.
- [ ] Migrate existing `Ingredient#category` + `Recipe#category` integer enums to `category_id` FKs; seed each account's category table with the current enum values so no operator sees a regression on first load.
- [ ] Replace the fixed `<select>` on ingredient + recipe forms with a searchable combobox (Stimulus-only, no JS framework): types to filter existing, "↵ Agregar **nueva categoría**" inline, same pattern on `/ingredients` + `/recipes` index filters.
- [ ] Internal preparations stay identifiable — the `bases` category is a seed row, not a flag. Keep the "esta receta es interna" boolean orthogonal.
- [ ] Out for v1: per-category sort, color tags, icons, drag-reorder.

#### Slice 2 — Proveedores (M)

- [ ] New `Supplier` model — `name`, `phone`, `whatsapp`, `notes`, `colonia`, `city`, `account_id`, soft-deletable.
- [ ] `/proveedores` index + new + edit (drawer form, same pattern as clients).
- [ ] New `SupplierIngredient` join — `supplier_id`, `ingredient_id`, `unit_cost_cents`, `last_bought_on`, `notes`. One ingredient ↔ many suppliers.
- [ ] Ingredient form — "Proveedores y precios" section: add a row per proveedor + price + unit. One row is flagged `is_default_cost_source: true`; the cost engine reads that one.
- [ ] Migration — existing `Ingredient#supplier_name` free-text values become auto-created `Supplier` rows with no phone/notes; default `SupplierIngredient` is seeded with the current `unit_cost_cents`.
- [ ] Nudge on the ingredient detail: "Tu mejor precio hoy es $X en [Proveedor]" when a non-default supplier is cheaper than the default.
- [ ] `Recipes::CostCalculator` keeps its signature — it just follows `ingredient.default_supplier_price` instead of `ingredient.unit_cost_cents`.

#### Slice 3 — Purchase ledger (L — the big one)

- [ ] New models: `Purchase` (`date`, `supplier_id` optional, `total_cents`, `notes`, `account_id`) + `PurchaseItem` (`purchase_id`, `ingredient_id`, `quantity`, `unit`, `unit_cost_cents`, `notes`).
- [ ] `/compras` CRUD: index (one row per Purchase), new, edit, show. Purchase form accepts multiple line items (same nested-rows pattern as the order form).
- [ ] Creating a `PurchaseItem` upserts the matching `SupplierIngredient#unit_cost_cents` + stamps `last_bought_on`, but does **not** retroactively recompute `Recipe#cost_cents_cached`. Cache recalc stays an explicit operator action ("Actualizar costos con precios nuevos"), so closed pedido margins never shift under the operator's feet.
- [ ] Unit conversions fold in — `Recipes::UnitConverter` normalizes the purchase unit against the ingredient's canonical unit so kg purchases update per-g prices cleanly.

#### Slice 4 — "Marcar como comprada" on the shopping list (S, once 3 lands)

- [ ] Each shopping-list line gets a "Marcar como comprada" action that opens a minimal drawer: qty-actually-bought, price-paid, proveedor (optional). Submitting creates a `PurchaseItem` under a day-scoped `Purchase`.
- [ ] "Listo" checkmark persists across sessions (it's no longer ephemeral — it reflects a real ledger row).
- [ ] Running tally at the top of the list: "Esta semana llevas $X en compras".

#### Slice 5 — Gastos reales en /reports/finance (S)

- [ ] Add a "Gastos" KPI + trendline to `/reports/finance` that sums `PurchaseItem.unit_cost_cents * quantity` over the window's purchase dates (not delivery dates — a shopping run on Tuesday belongs to Tuesday's expenses).
- [ ] "Margen real" badge alongside "Margen bruto" — the real-margin number uses actual purchase totals; the gross-margin number keeps using `OrderItem` cost snapshots. Both live on the same card so the operator can see the gap.
- [ ] CSV export adds the purchase lane.

### Out (explicit deferrals)

- **FIFO vs weighted-average cost accounting.** We track the *current default supplier price* only; FIFO waits for demand.
- **Stock depletion ledger.** Inflows only in v1. Auto-decrement when a pedido ships is a whole second mental model (batch yields, leftover carry-over) — out.
- **Auto-reorder alerts / low-stock notifications.** Depend on depletion.
- **Batch/yield tracking** ("esta olla de tamales rindió 20, vendí 18, perdí 2") — Phase 7 deferral, stays out.
- **Supplier payment tracking / accounts payable.** That's accounting software.
- **Retroactive recipe cost recomputation when a purchase lands.** Deliberately no. The operator triggers recalc explicitly.
- **Recipe versioning / price history.** Falls out naturally from the purchase ledger + supplier prices; surfacing it as a separate UI waits for explicit ask.

### Key decisions to lock before building

1. **Editable categories — one shared model or two (ingredient vs recipe)?** Proposed: one `Category` model with a `kind` enum. Cheaper today, splits cleanly later if the two evolve apart.
2. **Which supplier price drives the cost engine?** Proposed: an explicit `is_default_cost_source` flag per ingredient. "Lowest active" is surfaced as a nudge but never auto-applied — operators need to know *why* a cost changed.
3. **Does marking a purchase update the ingredient's unit cost?** Only the *specific supplier's* price for that ingredient. The default-cost-source choice stays the operator's.
4. **Stock depletion — in or out for v1?** Out. Inflows only. Promote when operators ask "why does my on-hand count not match reality?".
5. **Do recipes see retroactive cost changes on new purchases?** No. `OrderItem#unit_cost_cents` is snapshot-locked forever; `Recipe#cost_cents_cached` recomputes only on explicit operator action.
6. **Can a `Purchase` exist without a `Supplier`?** Yes — quick Costco run entries shouldn't force a proveedor row. Nullable FK, UI prompts "(sin proveedor)".

### Files to create / modify

**Models (new)** — `Category`, `Supplier`, `SupplierIngredient`, `Purchase`, `PurchaseItem`.
**Models (modify)** — `Ingredient` (swap `category` integer enum → `category_id`, drop `supplier_name` free text in favor of `SupplierIngredient`), `Recipe` (same category swap).
**Controllers (new)** — `CategoriesController`, `SuppliersController`, `PurchasesController`.
**Queries** — extend `Reports::Finance` with `purchases_total_cents_by_date`; new `Reports::RealMargin` service that joins purchases + delivered-pedido revenue for the window.
**Views / components** — category combobox (`Ui::ComboboxComponent`), `Suppliers::FormComponent`, `Purchases::FormComponent`, `ShoppingList::MarkBoughtComponent`, `Reports::ExpenseTrendComponent`.
**Routes** — `resources :categories` (scoped to ingredient + recipe via `kind`), `resources :suppliers` (also `/proveedores` alias), `resources :purchases` (also `/compras` alias). Update `Account::RESERVED_SLUGS` + run `bin/check_reserved_slugs`.
**Locales** — new keys under `panels.yml`: `categories.*`, `suppliers.*`, `purchases.*`, `shopping_list.mark_bought.*`, `reports.finance.expenses.*`.

### Effort estimate

| Slice | Rough effort | Unlocks |
|---|---|---|
| 1 — Editable categories | S | Small UX win; clean foundation for the supplier + purchase UIs |
| 2 — Proveedores + per-supplier prices | M | Real price comparison; prerequisite for the ledger |
| 3 — Purchase ledger | L | The meat of the phase — persistent, auditable compras |
| 4 — Mark-as-bought on shopping list | S | Ties the daily ops loop into the ledger |
| 5 — Gastos reales in /reports/finance | S | Makes the finance report honest |

**Recommended merge order: 1 → 2 → 3 → 4 → 5.** Categories and suppliers can ship independently in case Phase 9 takes longer than the 2–3 focused work-weeks it estimates — they're standalone operator wins.

### Verification (from clean DB + seed)

1. Add a new category "Dulces" on `/ingredients/new`. Refresh. Create a second ingredient; "Dulces" is in the combobox search.
2. Add two proveedores to "Harina de maíz" — Mercado $32/kg, Costco $28/kg. Flag Mercado as default. The recipe cost tree uses $32/kg.
3. Create a `Purchase` for Saturday with 2 kg harina at $29/kg from Costco. `SupplierIngredient[Costco,Harina]#unit_cost_cents` = 2900; Mercado row unchanged; recipe cost_cached unchanged.
4. Trigger "Actualizar costos con precios nuevos" — recipe cost_cached recomputes; new `OrderItem` rows snapshot the new cost; older `OrderItem` rows stay locked.
5. `/production/shopping-list` shows Saturday's run. Mark "Harina de maíz" as comprada with 2 kg at $29 — the line checkmark persists across reloads.
6. `/reports/finance?range=this_week` shows a "Gastos" KPI = $58; margen real reflects it.
7. `rubocop` / `brakeman` / `bin/check_reserved_slugs` / `bin/smoke_storefront_order` all stay clean.

---

## Phase 10 — Payments (deferred until demand)

Mexican-specific, lots of integration surface. **Defer until we have 10+ operators asking.** WhatsApp + the payment-pending chip + `mark_paid!` handle it until then.

- [ ] Mercado Pago link generation (v1.5 target — simplest wedge)
- [ ] SPEI reference capture on Payment
- [ ] Stripe Checkout for anticipos (v1.6)
- [ ] Payment reconciliation dashboard
- [ ] Customer-facing "Pagar anticipo" button on the confirmation page (currently only shows "Te contacto por WhatsApp")

---

## Phase 11 — Growth, retention, polish

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

1. ~~**Phase 4**~~ — shipped. The kitchen hears every pedido, the customer gets a tracked confirmation, and payment is a property (not a state).
2. ~~**Phase 5**~~ — shipped. Production planning + daily focus + runner view + bulk actions. The operator's morning routine lives on one page.
3. ~~**Phase 6**~~ — shipped. Schedule with exceptions (Agendario-style), email-verified two-step confirmation, the storefront delivery picker that actually respects operating modes, and the dish detail page.
4. ~~**Phase 7 (composable recipes)**~~ — shipped. Decomposition UI, cost tree, ingredient-impact panel, first-decomposition onboarding. `OrderItem#unit_cost_cents` now snapshots real composed cost at order time.
5. ~~**Phase 8 (finance & menu performance)**~~ — shipped. `/reports/finance` (KPI triptych + 8-week trend + day-by-day + CSV), `/reports/menu` (estrellas / estables / revisa estos), dashboard weekly snapshot, empty-state handling. The full BCG matrix stays deferred until we've got ≥60 days of pedido history per operator.
6. **Phase 9 next (catálogos, proveedores, compras)** — the operator-facing loop gets honest: editable categories, first-class suppliers with per-supplier prices, a persistent purchase ledger backing the shopping list, and "gastos reales" on the finance report. This is the phase that turns a read-only "lista de compras" into the operator's real expense record.
7. **Phase 10 (payments)** — still deferred. Waits for explicit operator demand (10+ asking). WhatsApp + the payment chip + `mark_paid!` keep the loop honest in the meantime.

Phase 11 is continuous; each ships a slice per quarter once the core loop is done.
