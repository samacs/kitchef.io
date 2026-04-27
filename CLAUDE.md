# Kitchef

Phone-first operations suite for Mexican home-food operators. Built with Rails 8, Hotwire, PostgreSQL, Valkey. Spanish-only UI, MXN-only money, optimized for iOS / Android-on-4G.

## Quick reference

- **Ruby** 4.0.2 (RVM gemset `kitchef.io`) · **Rails** ~8.1 · **PostgreSQL** 18 · **Valkey** 9
- **No Node.** Importmap + Propshaft. No ESbuild, no Webpack.
- **No Devise.** Rails 8 native auth (`rails generate authentication`).
- **No tests yet.** FactoryBot ships in the Gemfile but is unused; seeds use hardcoded pools of real Mexican names. Add FactoryBot back when we add a test suite.
- **Dev server:** `https://lvh.me:3000` — HTTPS via mkcert certs in `./ssl/` (gitignored, per-machine).
- **Docs:** `docs/PRD.md`, `docs/TRD.md` — read these when you need product or architectural context.

## Commands

```bash
# Development
bin/dev                                # overmind → foreman: web + css + sidekiq worker on SSL
docker compose up -d                   # Start PostgreSQL + Valkey
bundle exec rails db:seed              # Seed idempotent demo data (two accounts)
bundle exec rubocop                    # Lint (rubocop-rails-omakase)
bundle exec brakeman                   # Security scan
bin/check_reserved_slugs               # Verify top-level routes are in Account::RESERVED_SLUGS

# Database reset — Rails 8 uses schema.rb when available. To force a full
# migration replay (e.g. after editing an unshipped migration), delete the
# schema file first, then:
rm db/schema.rb && bundle exec rake db:migrate:reset && bundle exec rails db:seed

# Background jobs
bin/sidekiq -C config/sidekiq.yml      # Sidekiq worker (also runs under bin/dev)

# Code generation
bundle exec rails g model Foo          # Maintain correct migration order by hand
bundle exec annotaterb models          # Re-annotate after any migration
```

## Architecture

Monolithic Rails 8 app, server-rendered with Hotwire. No microservices, no separate frontend, no React.

```
Browser → Thruster → Puma (Rails 8)
  Controllers → Commands/Services/Queries → Models
  ViewComponent → ERB → Turbo Streams
         ↓              ↓            ↓
     PostgreSQL       Valkey      Sidekiq
```

### Multi-tenancy

One `Account` per operator. Every tenant-scoped model has `account_id`. Use `Current.account` in authenticated contexts — it's resolved in `ApplicationController#set_current_account` from the signed-in user's `owned_account`. Public storefront controllers use `@storefront` instead (no `Current.account`).

### Storefront theming (branded per-kitchen)

Each account picks one of ~10 curated palettes via `Accounts::Branding.palette` (default `bosque`) plus a light/dark default (`Accounts::Branding.theme_default`). `Storefronts::Palette.css_vars_for(account, dark:)` returns inline `--brand-1 / --brand-1-ink / --brand-1-soft / --brand-1-line` CSS variables the storefront layout injects per-request. The operator app NEVER receives these variables — it always ships the Kitchef deep-green accent. Only storefront views / components read `var(--brand-*)`. Don't reference `--brand-1` inside operator-app components.

### Routing (all English, no /panel prefix)

Public storefronts use **root-level slugs**: `kitchef.mx/cocina-de-elena`. The `Account::RESERVED_SLUGS` constant (194 entries in `app/models/account.rb`) blocks collisions with app routes. The catch-all storefront scope is **always last** in `config/routes.rb`. Run `bin/check_reserved_slugs` when adding any new top-level route — it fails CI on missing entries.

**Top-level operator routes** (no `/panel` prefix, no `Panel::` namespace):
`/orders`, `/clients`, `/recipes`, `/ingredients`, `/delivery-slots`, `/account`, `/subscription`, `/production`, `/reports/menu`, `/reports/finance`, `/onboarding/recipes/:id`.

**Auth:** `/sign-in`, `/sign-up`, `/sign-out`, `/reset-password`.
**Marketing:** `/pricing`, `/how-it-works`, `/faq`, `/legal/:doc`.
**Platform admin** (Kitchef team only): `/admin`.
**Dev email inbox:** `/letter_opener`.

### Root path dispatch via routing constraint

`/` has two handlers, picked by `UserConstraint`:

```ruby
# config/routes.rb
root "dashboards#show",
     constraints: UserConstraint,
     as: :authenticated_root     # signed-in operators

root "static_pages#show", defaults: { page: "home" }  # anonymous visitors
```

`app/constraints/` holds three classes (mirrors Agendario):
- `ApplicationConstraint` — base, expects `#authorized?`
- `UserConstraint` — has a valid `:session_id` cookie
- `AdminConstraint < UserConstraint` — `super && user.admin?`

The `/admin` namespace is gated by `AdminConstraint` at the routing layer (non-admins get a 404 that's indistinguishable from an unknown slug). `Admin::BaseController#require_admin` is belt-and-suspenders.

## Controllers

### Base classes

| Base | Purpose |
|---|---|
| `ApplicationController` | Everyone. Includes `Authentication` concern, sets `Current.account`, exposes `render_stub(title:, meta:)` for Phase 6 placeholders. |
| `AuthenticatedController` | Every operator-facing controller at the top level (Orders, Clients, Recipes, Ingredients, DeliverySlots, Accounts, Subscriptions, Dashboards, and the nested `Production::*`, `Reports::*`, `Onboarding::*`). Enforces `require_account`, sets `layout "panel"`. |
| `Storefronts::BaseController` | Public, unauthenticated. Resolves `@storefront` via `friendly_id`, catches `RecordNotFound` → branded not-found. |
| `Webhooks::BaseController` | `< ActionController::API`. No CSRF, no cookies, no views. |
| `Admin::BaseController` | Platform admin. `require_admin` redirect fallback + own layout. |

**There is no `Panel::` namespace.** Controllers sit flat at the top level; domain groupings live in `Production::`, `Reports::`, `Onboarding::` sub-namespaces so `/production/shopping-list` routes to `Production::ShoppingListsController`.

### Typical operator controller

```ruby
class RecipesController < AuthenticatedController
  expose :recipes, -> { Current.account.recipes.kept.saleable.positioned }
  expose :recipe
end
```

## The three patterns: Command / Service / Query

**Never put business logic in controllers or fat models.**

### Commands — write operations

One command per business action. Returns a `Result` with `.success?`, `.object`, `.errors`. Note the actual class is `Orders::Place` (file `app/commands/orders/place.rb`), **not** `Orders::PlaceOrder` — keep the real name.

```ruby
# app/commands/orders/place.rb
class Orders::Place < ApplicationCommand
  option :account
  option :params

  def call
    order = account.orders.create!(params)
    success(order)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  end
end
```

Use in controllers: `result = Orders::PlaceOrder.call(account: Current.account, params: order_params)`.

### Services — coordination, read-side logic, external integrations

```ruby
# app/services/recipes/cost_calculator.rb
class Recipes::CostCalculator < ApplicationService
  option :recipe
  def call
    # resolve cost tree...
  end
end
```

### Queries — database-heavy reads, reports

```ruby
# app/queries/reports/menu_engineering_matrix.rb
class Reports::MenuEngineeringMatrix < ApplicationQuery
  option :account
  def call
    # query and return structs, not AR objects
  end
end
```

All three use `Dry::Initializer` and expose a `.call(...)` class method.

### Naming

- `app/commands/<domain>/<verb>.rb` — `Orders::PlaceOrder`, `Recipes::Decompose`, `Ingredients::UpdatePrice`
- `app/services/<domain>/<noun>.rb` — `Recipes::CostCalculator`, `Recipes::CycleDetector`
- `app/queries/<domain>/<noun>.rb` — `Reports::MenuEngineeringMatrix`, `Production::WeeklyShoppingList`

## Composable recipes

The core differentiator. Recipes can be composed of ingredients AND/OR other recipes, arbitrarily deep. The UI adapts based on `account.settings.use_composable_recipes`:

- **Simple mode** (`false`, default): flat recipes with name + price + photo. No cost engine visible. A gentle prompt invites decomposition.
- **Advanced mode** (`true`): full component picker (ingredients + recipes), internal/saleable toggle, cost tree visualization, ingredient impact analysis.

The flag flips when the operator completes her first decomposition (via `Onboarding::CompleteFirstDecomposition` command) or opts in during signup.

### Key models

- `Recipe` — has `is_saleable` (appears on menu) and `yield_quantity` + `yield_unit` (how much one batch produces). Categories: `mains, starters, desserts, drinks, bases, other` (English keys, Spanish display via I18n).
- `RecipeComponent` — polymorphic join: `componentable` points to `Ingredient` or `Recipe`.
- `Ingredient` — leaf node, purchased from suppliers. Categories: `pantry, meats, dairy, produce, spices, other`.

### Key services

- `Recipes::CostCalculator` — bottom-up memoized tree traversal, returns cost in cents
- `Recipes::CycleDetector` — BFS from proposed child, runs in `RecipeComponent` `before_save`
- `Recipes::DependencyGraph` — recursive CTE, finds all recipes affected by a price change
- `Recipes::UnitConverter` — static conversion table (kg↔g, l↔ml), strict on cross-type

### Invariants

- Parent recipes always use the child's **cost**, never its `sale_price`
- Cycles are blocked at save time AND detected at calculation time (defense-in-depth)
- `cost_cents_cached` on `Recipe` is the fast path (monetize: `as: :cost_cached` — money-rails can't infer the `_cached` suffix)
- `OrderItem.unit_cost_cents` is a snapshot at order time — never recomputed retroactively

## ViewComponent

Use a component whenever there's logic in a template or a partial repeats. UI primitives live under `app/components/ui/` (`Ui::ButtonComponent`, `Ui::BadgeComponent`, `Ui::CardComponent`) and map directly to DESIGN.md specs. **We do not use Flowbite** — the token palette, typography, and component patterns in DESIGN.md are bespoke, and Flowbite's defaults would fight them everywhere.

```ruby
# app/components/ui/button_component.rb
class Ui::ButtonComponent < ApplicationComponent
  option :variant, default: -> { :default }   # :default, :primary, :ghost
  option :size,    default: -> { :md }        # :sm, :md
end
```

Components inherit from `ApplicationComponent` which extends `Dry::Initializer`.

Naming: `app/components/<domain>/<noun>_component.rb` with sidecar `.html.erb`.

## Language, code, and copy rules

**Code is English. Copy is Spanish via I18n.** Hard rule — two feedback memories say so.

### Code (identifiers, comments, config) — English

- Class names, method names, variable names, enum keys, AASM state names, Stimulus controller labels: all English (`placed`, `in_production`, `cash`, `transfer`, `pantry`, `meats`, `mains`, `desserts`, `delivery`, `pickup`, `free`, `pro`, `team`).
- Comments in controllers, models, initializers, migrations, bin scripts, env files: English.
- Commit messages: English.
- CLI output in `bin/*` scripts: English.

### Copy (anything the operator or storefront visitor sees) — Spanish es-MX via I18n

- Every user-facing string goes through `t(".key")` (lazy lookup) or `I18n.t("key")`.
- Locale files: `config/locales/es-MX.yml` (base) + per-domain splits under `config/locales/es-MX/` (`auth.yml`, `domain.yml`, `marketing.yml`, `panels.yml`, `errors.yml`, `ui.yml`).
- Default locale `:"es-MX"`, fallback `:es` (rails-i18n translations for framework messages).
- `tú` forms: *agrega, guarda, edita, elimina* — never `usted`.
- Mexican vocabulary: *pedido* not *orden*, *anticipo* not *depósito*, *colonia* not *código postal*, *platillo* not *producto*, *receta* not *recipe*, *ingrediente* not *ingredient*, *recolección* not *pickup*.
- Composable recipe vocabulary: *descomponer*, *receta interna*, *componente*, *receta base* / *preparación*.
- No English loanwords where Spanish works. No "optimiza tu workflow" energy. No "AI-powered" anywhere.

### View layer rules (no inline JS/CSS)

- **No inline `<script>` bodies in ERB.** Pre-paint boot code (theme init) lives in `app/javascript/theme_bootstrap.js` and is loaded via `javascript_include_tag "theme_bootstrap"` in `<head>`.
- **No inline `<style>` or `style=`.** Tailwind utility classes + tokens in `app/assets/tailwind/application.css`.
- **No `onclick=`.** Interactive behavior → Stimulus controllers in `app/javascript/controllers/`, with Spanish labels passed via `data-*-value` attributes.

## Money

Always MXN. Always `$` (never `MX$` or `USD`). Display: `$1,250.00`.

Every monetary column is `_cents` (BIGINT). Use `monetize :total_cents` in models. Format with `humanized_money_with_symbol`. One exception: `Recipe#cost_cents_cached` needs `monetize :cost_cents_cached, as: :cost_cached, allow_nil: true` because the non-standard `_cached` suffix defeats money-rails' inference.

## Phone numbers

Default country: MX. Store raw input in `phone`, normalized E.164 in `phone_normalized`. Display: `+52 333 123 4567`.

We validate with **Phonelib** (gem exposes `strict_check = true`, not `strict_validation`). `phony` is loaded for normalization only — don't use `validates :phone, phony_plausible: true`, which rejects bare-digit input that Phonelib accepts.

WhatsApp deep links via `WhatsappHelper#whatsapp_link(phone, message)`.

## Dates, times, delivery windows

Server stores UTC. Display via `local_time` helper (client-side formatting to user timezone). Default timezone: `America/Mexico_City`.

Formats: `12 de mayo de 2026` (formal), `12/05/2026` (short). Never `May 12, 2026`.

**Delivery slots and order delivery windows store integer minutes from midnight** (0..1440), not Postgres `time` or `datetime`. See `lib/time_of_day.rb` for `from_string("09:30") → 570` and `to_string(570) → "09:30"`. Models expose `*_hhmm` accessors for forms/views.

```ruby
# DeliverySlot and Order both use this pattern
slot.start_time_hhmm = "10:00"   # writes 600 to start_time (integer)
slot.start_time_hhmm             # → "10:00"
slot.duration_minutes            # → integer
```

Why integers: timezone-immune (a "Saturday 10am-2pm" slot is 10am in the operator's local time, not an absolute moment), arithmetic-friendly, easy range queries. Check constraints at the DB level enforce `start < end`, `0..1440`, valid `day_of_week`.

## Models — common concerns

```ruby
include HasPrefixedId.new(prefix: "acc")   # acc_, cli_, ing_, rec_, ord_, pay_
include HasSoftDelete                      # wraps discard: discarded_at, .kept scope
include AccountScoped                      # belongs_to :account + .for_account scope
```

- `has_paper_trail` on: `Client`, `Ingredient`, `Recipe`, `Order`
- `has_person_name` on: `User`, `Client` — **columns must be named `first_name` and `last_name`**; the gem doesn't let you override names.
- `friendly_id` on: `Account` (storefront URL), `Recipe` (recipe detail URLs)
- `positioned` on: most orderable models
- `aasm` on: `Order` — states (English): `placed → confirmed → in_production → ready → en_route → delivered → paid` (+ `canceled`). `en_route` only fires for `delivery_type: :delivery`; pickup/shipping skip it.

### English enum keys, Spanish display

Every `enum` stores English symbols in the DB; operator-facing labels live under `t("<domain>.<attr>.<value>")` in `config/locales/es-MX/domain.yml`:

```ruby
# Payment.method
enum :method, { cash: 0, transfer: 1, card: 2, mercado_pago: 3, other: 99 }, prefix: true
# Display: t("payment.methods.cash") → "Efectivo"

# Order.state (AASM), Order.delivery_type, Order.source
# Ingredient.category, Ingredient.unit
# Recipe.category, Recipe.yield_unit
# Subscription.plan — free/pro (display "Gratis"/"Pro" via I18n)
# Subscription.status
```

One exception: `mercado_pago` stays as-is (brand name).

### Cascading deletes

`Account.destroy` cascades to everything under it. The `has_many` declaration order in `Account` matters because dependent-destroy runs in declaration order, and `OrderItem → Recipe` FK constraints force `orders` to destroy before `recipes`/`ingredients`:

```ruby
# app/models/account.rb
has_many :orders,         dependent: :destroy   # must come first
has_many :clients,        dependent: :destroy
has_many :recipes,        dependent: :destroy
has_many :ingredients,    dependent: :destroy
# …
```

`Client.orders` uses `dependent: :nullify` — orders outlive clients for historical reporting. `Ingredient.recipe_components` and `Recipe.usages` use `dependent: :destroy` so account cascades work; controller-level confirmations protect operator-initiated deletes.

## Turbo & real-time

- Use Turbo Frames for in-page navigation within the operator app (avoid full reloads).
- Broadcast model changes via Turbo Streams to the operator's dashboard.
- `Order` broadcasts **two** channels: `[account, :orders]` for the operator kanban AND `[order, :status]` for the customer's per-order status page. The customer page subscribes via `<turbo-stream-from>` on the narrower channel so they never see unrelated orders from the same kitchen.

### **Every controller action that a Turbo-driven form redirects to must return HTML.**

Turbo Drive follows 302 redirects after `form_with` submissions and expects an HTML body to replace the DOM. If the target returns `text/plain` (e.g. `render plain: "..."`), Turbo silently bails, the URL bar doesn't change, and the sign-in flow looks broken. Use `render_stub(title: ...)` (defined on `ApplicationController`) for placeholders — it returns `text/html` from the shared `app/views/shared/stub.html.erb` template.

## Background jobs

Sidekiq with Valkey. Queues: `critical`, `default`, `mailers`, `notifications`, `imports`, `low`.

Sidekiq and `Rails.cache` share `Rails.application.config.redis_config` (set in `config/application.rb`) — change Valkey URL or driver in one place. `RedisClient.default_driver = :hiredis` for the whole app.

Scheduled jobs via `sidekiq-cron`: daily digest, birthday reminders, ingredient staleness checks, cost recalculation, sitemap generation. Schedule loads from `config/schedule.yml` if present (initializer is ready; file lands with the first cron job).

## File storage

ActiveStorage with `active_storage_validations`. Disk in dev, S3 in prod.

Images: max 5 MB, JPEG/PNG/WebP/HEIC, min 400×400. Variants: `thumb` (120×120), `card` (400×400), `hero` (1200×800).

## Email

- Dev: `letter_opener_web` at `/letter_opener` (was `/cartas` — renamed to use the gem's conventional mount path).
- Prod: Resend (`resend` gem).

## Billing

Stripe in MXN. Two tiers: *Gratis* (free, **40 pedidos/month** cap, enforced internally) and *Pro* at **$199 MXN/mes** or **$1,990 MXN/año** (2 meses gratis ≈ −16.7%). **14-day Pro trial, no card required**; trial-end auto-reverts to Free, never paywalls. No commission on operator sales, ever.

Subscription plan keys in code: `free`, `pro_monthly`, `pro_yearly`. Display via `t("subscription.plans.free") → "Gratis"`, `t("subscription.plans.pro_monthly") → "Pro · Mensual"`, `t("subscription.plans.pro_yearly") → "Pro · Anual"`. Stripe sandbox product: `prod_UPVu3WmAhMdJKm` (Kitchef Pro), prices `price_1TQgsp58g89ERoPrzw3U7GQ5` (mensual, 19900 MXN cents) + `price_1TQgsp58g89ERoPrPaVTz8A3` (anual, 199000 MXN cents). Save-flow coupon `ucUpunx9` (50% × 3 meses, repeating) for the cancel-flow's "muy caro" exit reason.

## Reserved slugs

`Account::RESERVED_SLUGS` blocks account names that would collide with app routes, brand names, or common web/SaaS paths (194 entries). Grouped in source by intent: Spanish app routes, English equivalents, cooking-domain terms, SaaS/auth/billing paths, tech/protocol paths, brand names.

When adding a new top-level route to `config/routes.rb`, add the path to `RESERVED_SLUGS` and run `bin/check_reserved_slugs` to verify. The CI script lives at `bin/check_reserved_slugs` and parses the actual route table — missing entries fail the build.

## Constraints (app/constraints/)

Routing-layer auth gates. Used exclusively for:
1. **Root path dispatch** — `UserConstraint` picks dashboard vs marketing home for the same `/` URL.
2. **Platform admin gating** — `AdminConstraint` blocks `/admin` routes for non-admins.

Not used for the operator app — `AuthenticatedController#before_action :require_authentication` (via the Rails 8 `Authentication` concern) handles redirects there and preserves `return_to_after_authenticating`. Controller-level auth is what you want for "sign in then come back to where I was."

## Style

- Rubocop Rails Omakase baseline.
- `annotaterb` after every migration. The installer wrote `lib/tasks/annotate_rb.rake` which runs automatically on `db:migrate`.
- No tests in v1 (deferred).
- Prefer boring, conventional Rails. This is a maintainable monolith, not an architecture demo.

## Design palette (DESIGN.md is the source of truth)

- **Background:** bone / warm off-white `#F8F6F1` — never pure white.
- **Ink (text):** `#0E1714` (near-black warm) / `#2F3A35` / `#6B7670` muted.
- **Accent:** deep green `#0A5A3C` — CTAs, active states, metric deltas. One accent, held back.
- **Surface:** `#FFFFFF` for cards (pure white is OK *on* bone).
- **Status:** positive shares the accent hue; `#B04E0E` warn; `#9B2B1E` error.
- **Fonts:** Instrument Serif (headlines, metrics), Inter (UI), JetBrains Mono (prices, deltas, kickers).
- **Never:** terracotta (retired), purple, rainbow palettes, gradient backgrounds, emoji-as-UI, pure `#FFFFFF` page backgrounds, pure `#000`.

Tokens registered in `app/assets/tailwind/application.css` via Tailwind v4's `@theme` directive. Dark mode flips token values under `.dark`; pre-paint script in `app/javascript/theme_bootstrap.js` loaded synchronously in `<head>` prevents FOUC.

## Example data conventions

When creating seeds, fixtures, or placeholder content:

- Real Mexican names: Carmen, Lupita, Elena, Marisol, Mariana, Don Mario (from a curated pool in `db/seeds.rb` — we dropped Faker, its `es-MX` locale was flaky).
- Real dishes: *tamal verde, pozole, enchiladas suizas, pastel de tres leches, agua de jamaica, champurrado*.
- Real colonias: Condesa, Del Valle, Chapalita, San Pedro Garza García, Providencia, Zona Esmeralda.
- Realistic 2026 prices: tamal $25–35, pastel $350–600, comida corrida $80–120.
- Two seed accounts: *Cocina de Elena* (simple mode) and *Taquería Don Mario* (advanced mode).
- Demo credentials: `elena@lvh.me` / `mario@lvh.me`, password `kitchef2026`.

## Gotchas worth knowing

1. **Rails 8 `db:migrate` uses schema.rb when it's ahead of migrations.** If you edit an unshipped migration, the next `db:migrate` may silently reuse the old schema. Delete `db/schema.rb` first, then `rake db:migrate:reset`.
2. **Turbo bails on non-HTML responses after a form submit.** Always return HTML from controllers that forms redirect to. Use `render_stub(title:, meta:)` for placeholders.
3. **`root_url` can drop port/protocol** without explicit `default_url_options`. We set them in `config/environments/development.rb` so redirects after sign-in keep `:3000` and `https://`.
4. **Noticed 3.0 has a generator bug** — class `ModelGenerator` in `install_generator.rb`. Use `rails railties:install:migrations FROM=noticed` directly.
5. **`Panel::` namespace does not exist.** Don't create it. Operator controllers are flat at the top level (`OrdersController`, `RecipesController`) with `Production::` / `Reports::` / `Onboarding::` for domain sub-groupings.
6. **Recipe#cost_cents_cached** needs an explicit `as: :cost_cached` in `monetize` — non-standard suffix.
7. **Account has_many declaration order is load-bearing.** Orders must declare before recipes/ingredients because `OrderItem` FK-references `Recipe`.
8. **`has_person_name` requires the columns to be `first_name` / `last_name`.** Can't override. That's why `Client` uses those names (TRD originally said `name_first` / `name_last`).

## Design Context

**Brand personality:** Calm. Confident. Artisanal. Quiet confidence — no flash, no startup energy. The cocinera is the hero, not the platform.

**Checkout emotional goal:** Delight + anticipation. "I can already smell the tamales." Tips feel generous not obligatory, payment reveals feel informative not bureaucratic.

**Design principles:**
1. Respect the cocinera — she's a CEO. Never condescend.
2. One accent, held back — deep green `#0A5A3C` only for CTAs and active states.
3. Typography carries the hierarchy — Instrument Serif for importance, Inter for function, JetBrains Mono for money.
4. Mexican-native, not translated — tú forms, pesos, colonias, platillos.
5. Quiet confidence over visual noise — no gradients, no emoji-as-UI, 150ms transitions.

Full design context lives in `.impeccable.md` at the project root.
