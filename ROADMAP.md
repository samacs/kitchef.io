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

- [ ] Recipe autosave on `/recipes/:id/edit` (form-autosave + `head :no_content` + photo-reupload guard via `form-autosave:success` event)
- [ ] Shipping fulfillment type (paquetería/couriers) — deferred with the enum intentionally minimal
- [ ] Live palette hex from `Ui::Contrast` instead of the pre-stored `ink` field — optional optimization
- [ ] Hide-Kitchef-branding enforcement wired to Pro subscription (currently always visible)

---

## Phase 4 — Order confirmation, notifications, comms (next)

The storefront can *accept* an order today. This phase makes the acceptance *feel* complete and reliable for both sides. **High-value, medium-effort.**

- [ ] Recipe autosave (moved from Phase 3 deferred; ship with this phase so `/recipes/:id/edit` matches `/account/edit` UX)
- [ ] Operator notification bell when a new storefront order lands
  - [ ] Noticed event `StorefrontOrderPlaced` targeted at the account owner
  - [ ] Delivery to `:database` + Action Cable so the top-bar bell badge increments live
  - [ ] `/notifications` inbox page
- [ ] Customer confirmation email
  - [ ] `StorefrontOrdersMailer#placed` with order recap + kitchen name + WhatsApp link
  - [ ] Dev: letter_opener preview; Prod: Resend
  - [ ] Skipped gracefully when the customer didn't enter an email
- [ ] WhatsApp deep-link on the confirmation page (pre-filled message: "Hola Elena, vengo con mi pedido ord_…")
- [ ] "One-click confirm" from the operator notification (marks pedido `:confirmed`, triggers an optional WhatsApp message to the client)
- [ ] End-to-end headless-browser smoke test
  - [ ] Guest places an order → confirmation page renders with status timeline
  - [ ] Operator's kanban morphs live, notification bell increments
  - [ ] Operator clicks "Confirmar" → customer page's timeline morphs without a reload
- [ ] Polish: checkout empty-cart guard, phone-format inline validation, delivery-date picker min-date
- [ ] Kitchen config: wire ordering-hours schedule editor (currently JSON-only via console)

---

## Phase 5 — Production planning & runner directions

The kitchen workflow that happens *between* order confirmation and delivery. **Medium-value until a kitchen has 20+ active pedidos per week.**

- [ ] `/production/weekly` — consolidated view of confirmed orders by day
- [ ] `/production/shopping-list` — flat ingredient needs aggregated from confirmed-but-not-ready orders (will be minimal without composable recipes; sugar-coated until Phase 8 lands)
- [ ] Prep-timeline view: "hacer masa domingo 5pm para entregas lunes"
- [ ] Delivery-slot capacity enforcement (use `interval_set`)
- [ ] Route planning: group delivery orders by colonia, minimal map view
- [ ] Runner-facing mini-UI (shareable per-order URL with addresses + map link, no auth)
- [ ] Bulk "Marcar en camino" for a colonia batch

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

1. **Phase 4 first** — the storefront accepting an order with no notification feels broken the first time a kitchen misses a WhatsApp message. Recipe autosave ships alongside since the pattern is proven.
2. **Then Phase 5 (production planning)** — the first operator who gets more than 10 pedidos/week will ask for this by the second week.
3. **Phase 8 (composable recipes)** is technically beautiful but low urgency — the simple-mode flat recipe is the happy path for ~90% of kitchens.
4. **Phase 7 (menu engineering)** only makes sense after ~60 days of history, which implies ~2 months of live users first.
5. **Phase 6 (payments)** comes after at least one kitchen has explicitly asked for it — until then, WhatsApp-for-payment is fine.

Phases 9 and 10 are continuous; each ships a slice per quarter once the core loop is done.
