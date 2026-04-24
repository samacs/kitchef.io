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

## Phase 9 — Catálogos, proveedores y compras (shipped)

**Context.** Phase 7 gave us real recipe costs. Phase 8 turned those costs into revenue + margin numbers. Phase 9 closed the other side of the ledger: editable categorías, first-class proveedores with per-supplier price history, and a persistent purchase ledger that feeds real "gastos" onto the finance report. Plus a batch of infrastructure the rest of the app benefits from (Geocodable concern, shared GeocodeJob + StaticMapJob, fixed-position flash region, Turbo live-search with debounce, drawer-form reliability fixes).

- [x] ~~`Category` model — per-account, `kind` enum (`ingredient` / `recipe`), soft-deletable, manual `position` column. Auto-seeds 12 default rows per new `Account` via `after_create :bootstrap_default_categories`.~~
- [x] ~~Migration swaps `Ingredient#category` + `Recipe#category` integer enums for `category_id` FKs; data migration backfills every row onto the seeded rows and drops the legacy column in the same deploy.~~
- [x] ~~`Ui::ComboboxComponent` + `combobox_controller.js` — searchable Stimulus-only picker with inline-create (`"↵ Agregar…"`). Keyboard nav, aria-activedescendant, CSRF-aware POST. Reused by categories, suppliers, ingredients, and clients pickers.~~
- [x] ~~`Supplier` model — `name`, `phone`, `whatsapp`, `rfc`, `street_address`, `colonia`, `city`, `notes`. MX phone normalization via Phonelib. Uses the `HasRfc` concern.~~
- [x] ~~`/proveedores` CRUD — index (with live search), new/edit drawer, drawer-only `content_for :drawer_only` opt-out of the layout's drawer shell.~~
- [x] ~~`SupplierIngredient` join — `unit_cost_cents`, `last_bought_on`, `is_default_cost_source`. Partial unique index enforces one default per ingredient. After-save callback re-caches `Ingredient#unit_cost_cents` from the default row, which in turn triggers Phase 7's `Recipes::DependencyGraph` cost cascade.~~
- [x] ~~Ingredient edit drawer "Proveedores y precios" panel — table of supplier rows, radio to pick default, cheaper-alternative nudge card, inline-create combobox.~~
- [x] ~~Migration — `BackfillSuppliersFromIngredients` materializes a `Supplier` row per distinct `Ingredient#supplier_name` value and seeds a default `SupplierIngredient` from the ingredient's current cost.~~
- [x] ~~`Purchase` + `PurchaseItem` models. `has_one_attached :receipt_photo` with three variants, `has_paper_trail`, soft delete, `before_save :recompute_total`. Supports `total_cents_override` for propinas/descuentos.~~
- [x] ~~`Purchases::Create` command wraps the whole cascade (purchase → items → supplier_ingredient upsert with unit-converted price → ingredient cost cache → recipe recompute) in a single transaction.~~
- [x] ~~`/compras` mobile-first form — fecha picker, proveedor combobox with inline-create, receipt photo (`capture="environment"` for direct camera), dynamic line-item rows via `purchase-items` Stimulus controller, sticky running total, big numeric keyboards everywhere.~~
- [x] ~~`/compras.csv` export — columns `fecha, proveedor, ingrediente, cantidad, unidad, precio_unitario_mxn, subtotal_mxn, notas`. BOM-prefixed for Excel on es-MX.~~
- [x] ~~"Marcar como comprada" drawer on `/production/shopping-list` — pre-fills qty + default supplier + last price; submit appends to today's `Purchase` for that supplier (or creates one). Running weekly-totals strip at the top.~~
- [x] ~~Shopping-list ingredient row renders a persistent `✓ $price/unit · Supplier` line once a purchase lands — the former ephemeral checkbox is now backed by real ledger data.~~
- [x] ~~`Reports::Finance` grows `purchases_cents` + `purchase_count` + `real_margin_cents` + `real_margin_pct`. New "Gastos en ingredientes" KPI card on `/reports/finance` (only when the window has ≥1 purchase), plus a "Margen real" badge alongside Margen bruto. Day breakdown gains a Gastos column. CSV adds `gastos_mxn` + `margen_real_mxn` columns.~~
- [x] ~~Seeds: 4 suppliers for Mario, 2 for Elena, `SupplierIngredient` default rows backfilled from the legacy `supplier_name`, 4 realistic purchases on Mario's ledger across the last 3 weeks, a secondary cheaper-than-default row on 3 ingredients so the "Marcar como default" nudge surfaces on demo.~~

### Bonus work (shipped alongside Phase 9 — not in the original plan)

- [x] ~~`HasRfc` concern — MX SAT RFC (12/13 char) format validation, auto-normalizes (uppercase, strips dashes/spaces). Included on `Client` and `Supplier`, optional everywhere, folded into both `.search` scopes.~~
- [x] ~~Turbo live-search with debounce — new `search-debounce` Stimulus controller + `_results` Turbo-frame partials on `/clients` + `/proveedores`. Typing fires `requestSubmit()` after 250ms idle; Enter submits immediately; `data-turbo-action="advance"` keeps the URL in sync.~~
- [x] ~~`Geocodable` concern — shared `has_one_attached :static_map` (two variants: `:thumb` for kanban/list, `:card` for drawer banners), `geocoded?` / `needs_geocoding?` / `geocoding_on_cooldown?`, `geocodable_by :col, :col2, :col3`. `Order` + `Supplier` both include it.~~
- [x] ~~Polymorphic `GeocodeJob` + `StaticMapJob` — take a GlobalID, work against any Geocodable record. Replaced the per-model `GeocodeOrderJob` / `GeocodeSupplierJob` / `SupplierStaticMapJob` files. Static map PNG is fetched once per coord change and served from ActiveStorage so the kanban stops billing Google per paint.~~
- [x] ~~`MapsHelper` refactored — `static_map_image_tag(record, variant:)` serves cached attachment variants; live Google URL is a transient fallback for the post-geocode pre-cache window.~~
- [x] ~~Fixed-position flash region — `shared/_flash_region.html.erb` mounted once per layout, pinned strip at the top on mobile, floats top-right on `sm+`. `pointer-events-none` on the container, `-auto` on toasts so empty space is click-through. Removed 17 inline flash renders from views so flashes never shift page content.~~
- [x] ~~Drawer reliability fixes — `content_for :drawer_only, "1"` opt-out so link-prefetch / page-reload responses don't duplicate `drawer_content` frames; `close_drawer_and_refresh` passes a unique `request_id: SecureRandom.uuid` so the morph refresh fires on the submitting tab instead of being deduped by `broadcasts_refreshes_to`'s request-id machinery; `form-autosave` fetches now seed `Turbo.session.recentRequests` + send `X-Turbo-Request-Id` so `broadcasts_refreshes_to` no longer closes open drawers mid-edit.~~
- [x] ~~Inline-create cross-wired on every combobox (categorías, proveedores, ingredientes) — `SuppliersController#create` + `IngredientsController#create` accept both nested (form) and flat (combobox JSON) param shapes; inline-created ingredients default to `unit: "kg"` and the account's first category.~~
- [x] ~~Dev-env fixes: `config.default_url_options` added to `development.rb` so Rails 8.1's `ActiveStorage::AnalyzeJob` deserialization stops raising; `SSL_CERT_FILE` + `SSL_CERT_DIR` pinned in `.env.development` so Sidekiq workers don't hit "certificate verify failed" on transient DNS resolutions.~~

### Phase 9 deferred (small but worth naming)

- [ ] Stock depletion — still inflow-only. Revisit when operators ask "¿cuánto me queda de X?".
- [ ] Fixed costs (rent, gas, packaging) — **Phase 10's main goal**. Net profit needs them.
- [ ] FIFO / weighted-average accounting — current-default-supplier price remains the v1 basis.
- [ ] Auto-reorder alerts / low-stock notifications — depend on depletion.
- [ ] Batch / yield tracking — Phase 7 deferral, still out.
- [ ] Retroactive recipe cost recomputation on closed pedidos — deliberately locked.
- [ ] Per-category color/icon, drag-reorder, `/account/categorias` management page — basic CRUD is enough for v1.
- [ ] Supplier tags / payment terms / calificar-proveedor — name + notes holds the line.

---

## Phase 10 — Rentabilidad real: costos fijos y utilidad neta (next)

**Context.** Phase 9 made "gastos reales" honest at the variable-cost level — every kilo of harina, every kg de arrachera, every bolsa de empaque that runs through a proveedor is now in the ledger. But that's only half of what an operator actually spends. Rent, gas, platform commissions, Didi subscriptions — those are fixed (or semi-fixed) monthly costs that are just as real, and they're invisible on `/reports/finance` today. An operator reading "Margen bruto 62%" thinks she's doing better than she is.

Phase 10 closes the other half of the ledger: fixed-cost tracking, a real "utilidad neta" number alongside the gross margin we already show, and an honest-to-god "costo fijo por pedido" tile so the operator can price with her head, not her gut.

**Why now.** Phase 8's margins are accurate-for-variable. Phase 9 made variable gastos honest. The next question every operator asks after seeing her gross margin is "sí, pero ¿cuánto me llevo a casa después de la renta?". Answering requires fixed costs modeled first. This is also the phase that lets operators start pricing with real net-margin targets instead of flat "60% bruto y a ver".

**Why this is smaller than Phase 9.** No new user workflow, no drawer-form dance, no ledger-with-cascade. It's a thin model + a one-screen editor + two new cells on the finance report. The only real decision to lock is the allocation method (prorate monthly rent across days vs. spike it on the billing day) — and we've got a proposal for that below.

### Goals

1. Operator records her monthly rent + gas + platform fees in under 60 seconds at `/costos-fijos`.
2. `/reports/finance` shows **Utilidad neta** (revenue − variable − fixed) + **Costo fijo por pedido** tiles alongside the existing margin cards.
3. Per-pedido packaging (cajas, bolsas, etiquetas) optionally becomes an explicit field so the cost appears in the variable bucket where it belongs, not in the fixed catch-all.
4. Fixed-cost entries can have `end_date`s so an operator who moves mid-year doesn't see her historical report jump around.
5. Dashboard weekly snapshot gets a third line: "Utilidad neta" (hidden until at least one fixed cost is logged — no hard zeros).

### Scope

#### Slice 1 — Categorías de costos fijos (S)

- [ ] New `FixedCostCategory` model — per-account, `kind` enum (`rent` / `utilities` / `packaging` / `platform` / `other`), `name`, `position`, soft-deletable.
- [ ] `Account#after_create :bootstrap_fixed_cost_categories` seeds five rows: Renta, Gas y servicios, Empaque, Plataformas (Didi/Rappi/Uber), Otros.
- [ ] Inline-create picker via the existing `Ui::ComboboxComponent` — same pattern as Phase 9's category work.

#### Slice 2 — Registro de costos fijos (M)

- [ ] New `FixedCost` model — `account_id`, `fixed_cost_category_id`, `amount_cents`, `recurrence` enum (`monthly` / `weekly` / `yearly` / `one_time`), `start_date`, `end_date` (nullable), `notes`, `cost_per_pedido_cents` (nullable, see Slice 4).
- [ ] `/costos-fijos` index + drawer form CRUD. Mobile-first. Reuse the suppliers drawer pattern wholesale.
- [ ] `FixedCosts::AllocationForWindow` service — given `(account, starting, ending)`, returns `{ total_cents:, by_category: { category_id → cents } }`. Monthly entries prorate as `amount × days_in_window / 30`; weekly as `amount × days / 7`; yearly as `amount × days / 365`; one-time entries that fall inside the window contribute their full amount.
- [ ] Paper-trail on `FixedCost` so the operator can see when she raised/lowered a recurring cost.
- [ ] Soft-delete stays on (`HasSoftDelete`) because a discarded cost shouldn't vanish from historical reports that already ran against it.

#### Slice 3 — Utilidad neta en /reports/finance (S)

- [ ] Extend `Reports::Finance#call` — add `fixed_costs_cents` + `net_profit_cents` + `net_profit_pct` + `fixed_costs_by_category` fields on `PeriodStats`. One extra SQL round-trip for the period's fixed-cost allocation.
- [ ] New KPI card: **Utilidad neta** = revenue − variable (real purchases) − fixed allocation. Shown alongside Margen bruto + Margen real. Hidden when no fixed costs exist; nudge card replaces it: *"Agrega tu renta y gastos fijos para ver tu utilidad real."*
- [ ] New tile: **Costo fijo por pedido** = fixed allocation ÷ `order_count` in window (when `order_count > 0`). Copy: *"Qué tanto tienes que pagar por cada pedido solo por existir."*
- [ ] Day-by-day breakdown adds a `fixed` column (muted when zero — most days will be).
- [ ] CSV export adds `costo_fijo_mxn`, `utilidad_neta_mxn`, `pct_utilidad_neta` columns.
- [ ] Dashboard weekly snapshot (`Dashboards::WeeklySnapshotComponent`) gets a third line "Utilidad neta" when at least one fixed cost exists for the account.

#### Slice 4 — Empaque por pedido (S)

- [ ] New `Accounts::Settings.default_packaging_cents` — the per-pedido flat packaging fee the operator pays regardless of dish (bolsas, servilletas).
- [ ] `/account/edit` gains a small "Empaque por pedido" input in the config section.
- [ ] `Order#packaging_cents` column (bigint, default 0) — hydrated from the account default at `Orders::Place` + `Orders::Update`; manually overridable on the order drawer ("Empaque extra" input, muted when it matches the default).
- [ ] `Reports::Finance` folds `SUM(orders.packaging_cents)` into the window's variable-cost total (treated as COGS, not fixed).
- [ ] Kanban card footer shows the packaging sub-line under Total when nonzero.

#### Slice 5 — Empaque por receta (XS)

- [ ] `Recipe#packaging_cents` column — for dishes where packaging is structurally tied to the dish (pastel en caja grande vs. un tamal en hoja).
- [ ] `OrderItem#unit_cost_cents` snapshots now include the recipe's packaging cost at order time, same as cost_cached behavior.
- [ ] Order total = sum(items.unit_price × qty) + orders.packaging_cents + Σ(items.recipe.packaging_cents × qty). Recompute hook mirrors the existing total_cents cascade.

### Out (explicit deferrals)

- **Stock depletion / inventario en tiempo real.** Still inflow-only. Promote when operators ask "¿cuánto me queda de X?".
- **Per-pedido net profit breakdown.** The aggregate "Costo fijo por pedido" tile is v1. Showing "este pedido te dejó $X después de todo" needs per-pedido allocation math that's its own phase.
- **Multi-kitchen / multi-branch fixed cost split.** One account = one kitchen, one rent number. Multi-branch waits for explicit demand.
- **SAT / CFDI / IVA-aware fixed cost categorization.** The ledger CSV is the v1 hand-off to the contador.
- **Payment / cuentas por pagar tracking for fixed costs.** "¿Le pagué la renta a Don José este mes?" is accounting-software territory. Out.
- **Automatic scrape of bank statements / invoice OCR.** Manual entry is enough at the operator scale we serve.
- **Currency other than MXN.** Still MXN everywhere.
- **Stripe / Mercado Pago subscription enforcement (Kitchef's own Pro tier gate).** Orthogonal revenue work; lands on its own phase when we hit 10+ operators asking.

### Key decisions to lock before building

1. **Monthly prorate vs. allocate-when-billed?** Proposed: **prorate**. Rent = $15,000/mes starting Jan 1 → a Jan 1–15 window shows $7,500 (15/30). Allocate-when-billed would spike $15k on Jan 1 and show $0 the other days — noisy on weekly/daily views and fights the operator's mental model of "renta diaria".
2. **"Costo fijo por pedido" denominator?** Pedidos **delivered** in the window. `placed` + `canceled` don't count. Matches the revenue basis the Margen cards use.
3. **Empaque — flat per-order, per-recipe, or both?** Both, additively. Account default = flat per-order baseline; `Recipe#packaging_cents` adds on top for dishes that carry their own packaging cost.
4. **Does a mid-period edit to a FixedCost rewrite history?** Yes — reports re-query live against the current state. For immutable history, the operator closes out the old row (`end_date`) and creates a new row with the new amount. Paper-trail captures the audit.
5. **Does the dashboard snapshot include utilidad neta?** Yes, as a third line, only when at least one `FixedCost` exists for the account. Operators who haven't logged their rent see the existing two-line snapshot unchanged.
6. **Does Phase 10 share `Category` with Phase 9's ingredient/recipe categories?** No. Separate `FixedCostCategory` model. Kinds evolve independently and the Phase 9 `Category.kind` enum is already split by domain.
7. **Should 31-day vs. 28-day months matter for prorate?** No. Flat 30 for monthly, 7 for weekly, 365 for yearly. The 0–2 day drift per period is well under the operator's own rounding.

### Files to create / modify

**Models (new)** — `FixedCostCategory`, `FixedCost`.
**Models (modify)** — `Order` (`packaging_cents` field, recompute hook), `Recipe` (`packaging_cents` optional), `Account` (`bootstrap_fixed_cost_categories` after_create).
**Settings** — extend `Accounts::Settings` StoreModel with `default_packaging_cents`.
**Controllers (new)** — `FixedCostCategoriesController` (thin, inline-create only — no management page in v1), `FixedCostsController`.
**Services** — `FixedCosts::AllocationForWindow`.
**Queries** — extend `Reports::Finance` with fixed-cost aggregation + net-profit math.
**Views / components** — `fixed_costs/index`, `fixed_costs/_form`, `Reports::NetProfitKpiCardComponent`, day breakdown grid bump, dashboard snapshot update, `/account/edit` packaging input, order drawer packaging override input, kanban card packaging sub-line.
**Migrations** — `create_fixed_cost_categories`, `seed_default_fixed_cost_categories`, `create_fixed_costs`, `add_packaging_cents_to_orders`, `add_packaging_cents_to_recipes` (Slice 5).
**Routes** — `resources :fixed_costs, path: "costos-fijos"`, `resources :fixed_cost_categories, only: %i[create destroy]`. Update `Account::RESERVED_SLUGS` with `costos-fijos`, `costos`, `fixed-costs`, `fijos`, `empaque`, `packaging`, `utilities`, `renta`, `rent`. Run `bin/check_reserved_slugs`.
**Locales** — new `panels.yml` keys: `fixed_costs.*`, `fixed_cost_categories.*`, `reports.finance.net_profit.*`, `reports.finance.expenses.fixed_*`, `orders.form.packaging.*`, `dashboard.weekly_snapshot.net_profit_*`.
**Seeds** — Mario's account gets four `FixedCost` rows (renta $15k mensual, gas $2k mensual, Didi comisión $500 semanal, empaque incluido en `default_packaging_cents = 800`). Elena stays minimal (renta $8k mensual).

### Verification (from clean DB + seed)

1. **Empty state.** Fresh Elena account with no fixed costs → `/reports/finance` shows Margen bruto + Margen real but no Utilidad neta card. Dashboard snapshot shows two lines.
2. **Record rent.** Add `Renta = $15,000 mensual, starts 2026-04-01`. `/reports/finance?range=this_week` (Mon–Sun, 7 days) → Utilidad neta card appears; fixed-cost allocation reads $3,500 (7 × $500/day).
3. **Multiple recurrences.** Add `Plataforma = $500 semanal, starts 2026-04-01`. Weekly window shows $500 straight. Monthly window shows $2,000.
4. **Cost-per-pedido tile.** 12 pedidos delivered in the week, $3,966.67 fixed allocation → tile reads $330.56/pedido.
5. **End-dated cost.** Edit `Renta#end_date = 2026-04-15` → May window shows $0 rent contribution.
6. **Paper-trail.** Change `Renta` amount from $15k to $17k → `Renta.versions.last` carries the old amount + timestamp.
7. **Packaging per order.** Set `default_packaging_cents = 1000`. Place a new pedido for 3 tamales → kanban card sub-line shows "+$10 empaque". Finance day breakdown rolls the $10 into that day's `cogs` column.
8. **Per-recipe packaging.** Give "Pastel de tres leches" `packaging_cents: 3500`. Order 2 pastels → `OrderItem#unit_cost_cents` snapshot includes $35 packaging per pastel.
9. **CSV export.** `/reports/finance?range=this_week&format=csv` carries the new `costo_fijo_mxn`, `utilidad_neta_mxn`, `pct_utilidad_neta` columns; BOM + Excel-friendly.
10. **Dashboard snapshot.** `/` shows "Utilidad neta" line; clicking it navigates to `/reports/finance?range=this_week`.
11. **Lint / security.** `rubocop` clean, `brakeman -q --no-progress` clean, `bin/check_reserved_slugs` green, `bin/smoke_storefront_order` 19/19.
12. **No regressions.** `/orders`, `/recipes`, `/ingredients`, `/proveedores`, `/compras`, `/production`, `/production/shopping-list`, storefront checkout — all render and function as before.

### Effort estimate

| Slice | Rough effort | Unlocks |
|---|---|---|
| 1 — Categorías de costos fijos | S | Foundation for Slice 2 |
| 2 — Registro de costos fijos | M | Operator logs her monthly reality |
| 3 — Utilidad neta en finance | S | The number every operator actually cares about |
| 4 — Empaque por pedido | S | Moves per-order packaging into variable where it belongs |
| 5 — Empaque por receta | XS | Skip if pressed for time; can land later as a follow-up |

**Recommended merge order: 1 → 2 → 3 → 4 → 5.** Slices 1–3 are the minimum viable phase and can ship together. Slice 4 is a clean follow-up once fixed costs are real. Slice 5 is a nice-to-have — some recipes (pasteles, pozole en olla) carry their own packaging baseline and the account-default can't cover that. Total phase: **~1 focused work-week**.

### Open questions (low-stakes, decide during build)

- **Should fixed-cost rows show on `/reports/finance` as a separate trend line?** Probably not in v1 — one line on the dashboard + the KPI card is enough. If an operator asks "when did my rent go up?", she opens `/costos-fijos` and reads paper-trail. Revisit if two operators ask for a trendline.
- **Negative `amount_cents` (e.g., `descuento del casero`) — allow?** Proposed: no. An operator who wants to reduce a fixed cost edits the row. Negative amounts muddy the semantics.
- **Should packaging cost flow into the cost engine's `Recipe#cost_cents_cached`?** Probably yes for Slice 5 (recipe packaging), so the cost tree surfaces it. The per-order baseline stays on the order, not the recipe.

---

## Phase 11 — Payments (deferred until demand)

Mexican-specific, lots of integration surface. **Defer until we have 10+ operators asking.** WhatsApp + the payment-pending chip + `mark_paid!` handle it until then.

- [ ] Mercado Pago link generation (v1.5 target — simplest wedge)
- [ ] SPEI reference capture on Payment
- [ ] Stripe Checkout for anticipos (v1.6)
- [ ] Payment reconciliation dashboard
- [ ] Customer-facing "Pagar anticipo" button on the confirmation page (currently only shows "Te contacto por WhatsApp")

---

## Phase 12 — Growth, retention, polish

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
6. ~~**Phase 9 (catálogos, proveedores, compras)**~~ — shipped. Editable categorías, first-class proveedores with per-supplier price history, persistent purchase ledger feeding the shopping list + finance report's "gastos reales" + "margen real" badge. Plus the `Geocodable` concern, polymorphic `GeocodeJob` + `StaticMapJob`, cached static-map attachments, fixed-position flash region, Turbo live-search with debounce, and a batch of drawer/autosave reliability fixes that benefit every surface. The operator's lista de compras is now the operator's real expense record.
7. **Phase 10 next (rentabilidad real — costos fijos y utilidad neta)** — the last piece to make `/reports/finance` tell the operator's actual take-home number. Fixed-cost tracking (renta, gas, plataformas, empaque), real Utilidad Neta alongside Margen bruto + Margen real, "Costo fijo por pedido" tile, and per-pedido packaging that moves into the variable bucket where it belongs. Narrower than Phase 9 — one model + one editor + two new cells on the report, ~1 focused work-week.
8. **Phase 11 (payments)** — still deferred. Waits for explicit operator demand (10+ asking). WhatsApp + the payment chip + `mark_paid!` keep the loop honest in the meantime.

Phase 12 is continuous; each ships a slice per quarter once the core loop is done.
