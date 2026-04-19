# Kitchef

Phone-first operations suite for Mexican home-food operators. Built with Rails 8, Hotwire, PostgreSQL, Valkey. Spanish-only, MXN-only, optimized for Android-on-4G.

## Quick reference

- **Ruby** ~4.0.1 · **Rails** ~8.1 · **PostgreSQL** 18 · **Valkey** 9
- **No Node.** Importmap + Propshaft. No ESbuild, no Webpack.
- **No Devise.** Rails 8 native auth.
- **No tests yet.** FactoryBot + Faker are for seeds only.
- **Docs:** `docs/PRD.md`, `docs/TRD.md`, `docs/BOOTSTRAP_PROMPT.md` — read these when you need product or architectural context.

## Commands

```bash
# Development
bin/dev                                # Start Rails + Tailwind watcher
docker compose up -d                   # Start PostgreSQL + Valkey
rails db:create db:migrate db:seed     # Set up database with demo data
bundle exec rubocop                    # Lint (rubocop-rails-omakase)
bundle exec brakeman                   # Security scan
bin/check_reserved_slugs               # Verify no top-level route is missing from RESERVED_SLUGS

# Background jobs
bundle exec sidekiq                    # Start Sidekiq worker

# Code generation
rails g model Foo                      # Always add to correct migration order
bundle exec annotaterb models          # Run after migrations to update schema annotations
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

One `Account` per operator. Every tenant-scoped model has `account_id`. Use `Current.account` in authenticated contexts. Public storefront controllers use `@storefront` instead (no `Current.account`).

### Routing

Public storefronts use **root-level slugs**: `kitchef.mx/cocina-de-elena`. The `Account::RESERVED_SLUGS` constant blocks collisions with app routes. The catch-all storefront scope is **always last** in `config/routes.rb`. Run `bin/check_reserved_slugs` when adding any new top-level route.

Authenticated panel lives under `/panel/*`. Marketing pages at `/precios`, `/como-funciona`, etc.

## The three patterns: Command / Service / Query

**Never put business logic in controllers or fat models.**

### Commands — write operations

One command per business action. Returns a `Result` with `.success?`, `.object`, `.errors`.

```ruby
# app/commands/orders/place_order.rb
class Orders::PlaceOrder < ApplicationCommand
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

Use in controllers: `result = Orders::PlaceOrder.call(account: Current.account, params: order_params)`

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

- `Recipe` — has `is_saleable` (appears on menu) and `yield_quantity` + `yield_unit` (how much one batch produces)
- `RecipeComponent` — polymorphic join: `componentable` points to `Ingredient` or `Recipe`
- `Ingredient` — leaf node, purchased from suppliers

### Key services

- `Recipes::CostCalculator` — bottom-up memoized tree traversal, returns cost in cents
- `Recipes::CycleDetector` — BFS from proposed child, runs in `RecipeComponent` `before_save`
- `Recipes::DependencyGraph` — recursive CTE, finds all recipes affected by a price change
- `Recipes::UnitConverter` — static conversion table (kg↔g, l↔ml), strict on cross-type

### Invariants

- Parent recipes always use the child's **cost**, never its `sale_price`
- Cycles are blocked at save time AND detected at calculation time (defense-in-depth)
- `cost_cents_cached` on `Recipe` is the fast path for dashboards; live `CostCalculator` for detail views
- `OrderItem.unit_cost_cents` is a snapshot at order time — never recomputed retroactively

## ViewComponent

Use a component whenever there's logic in a template or a partial repeats. Flowbite primitives are always wrapped in our own `app/components/ui/` components — never reference raw Flowbite class strings in views.

```ruby
# app/components/ui/button_component.rb
class Ui::ButtonComponent < ApplicationComponent
  option :variant, default: -> { :primary }
  option :size, default: -> { :md }
  # ...
end
```

Components inherit from `ApplicationComponent` which extends `Dry::Initializer`.

Naming: `app/components/<domain>/<noun>_component.rb` with sidecar `.html.erb`.

## Language & locale rules

**Every user-facing string in Spanish (es-MX).** No exceptions.

- `tú` forms: *agrega, guarda, edita, elimina* — never `usted`
- Mexican vocabulary: *pedido* not *orden*, *anticipo* not *depósito*, *colonia* not *código postal*, *platillo* not *producto*, *receta* not *recipe*, *ingrediente* not *ingredient*
- Composable recipe vocabulary: *descomponer* (decompose), *receta interna* (internal recipe), *componente* (component), *receta base* or *preparación* (base preparation)
- No English loanwords where Spanish works. No "optimiza tu workflow" energy.
- No "AI-powered" anywhere.
- All I18n keys live under `config/locales/es-MX.yml` and domain-specific files under `config/locales/es-MX/`

## Money

Always MXN. Always `$` (never `MX$` or `USD`). Display: `$1,250.00`.

Every monetary column is `_cents` (BIGINT). Use `monetize :total_cents` in models. Format with `humanized_money_with_symbol`.

## Phone numbers

Default country: MX. Store raw input in `phone`, normalized E.164 in `phone_normalized`. Display: `+52 333 123 4567`.

WhatsApp deep links via `WhatsappHelper#whatsapp_link(phone, message)`.

## Dates & times

Server stores UTC. Display via `local_time` helper (client-side formatting to user timezone). Default timezone: `America/Mexico_City`.

Formats: `12 de mayo de 2026` (formal), `12/05/2026` (short). Never `May 12, 2026`.

## Models — common concerns

```ruby
include HasPrefixedId     # acc_, cli_, ing_, rec_, ord_, pay_
include HasSoftDelete     # wraps discard: discarded_at, .kept scope
include AccountScoped     # belongs_to :account, default_scope considerations
```

- `has_paper_trail` on: `Client`, `Ingredient`, `Recipe`, `Order`
- `has_person_name` on: `User`
- `friendly_id` on: `Account` (storefront URL), `Recipe` (recipe detail URLs)
- `positioned` on: most orderable models (scoped per TRD §4)
- `aasm` on: `Order` — states: `pedido → confirmado → en_produccion → listo → entregado → pagado` (+ `cancelado`)

## Controllers

### Panel controllers (authenticated)

Inherit from `Panel::BaseController`. Use `decent_exposure`:

```ruby
class Panel::RecipesController < Panel::BaseController
  expose :recipes, -> { Current.account.recipes.kept.saleable.positioned }
  expose :recipe
end
```

### Storefront controllers (public, unauthenticated)

Inherit from `Storefronts::BaseController`. Resolve account via slug:

```ruby
# @storefront is set by BaseController from params[:slug]
# Never set Current.account in storefront controllers
```

### Webhook controllers

Inherit from `Webhooks::BaseController` (ActionController::API). Skip CSRF. Verify signatures.

## Turbo & real-time

- Use Turbo Frames for in-page navigation within the panel (avoid full reloads)
- Broadcast model changes via Turbo Streams to the operator's dashboard
- `Order` broadcasts to `[account, :orders]` — kanban column updates in real time
- Public storefronts do NOT broadcast (no open ActionCable stream)

## Background jobs

Sidekiq with Valkey. Queues: `critical`, `default`, `mailers`, `notifications`, `imports`, `low`.

Scheduled jobs via `sidekiq-cron`: daily digest, birthday reminders, ingredient staleness checks, cost recalculation, sitemap generation.

## File storage

ActiveStorage with `active_storage_validations`. Disk in dev, S3 in prod.

Images: max 5 MB, JPEG/PNG/WebP/HEIC, min 400×400. Variants: `thumb` (120×120), `card` (400×400), `hero` (1200×800).

## Email

- Dev: `letter_opener_web` at `/cartas`
- Prod: Resend (`resend` gem)

## Billing

Stripe in MXN. Free tier (20 pedidos/month) enforced internally. Pro at $249 MXN/month. No commission on operator sales, ever.

## Reserved slugs

`Account::RESERVED_SLUGS` blocks account names that collide with app routes. When adding a new top-level route to `config/routes.rb`, **also add the path to `RESERVED_SLUGS`** and run `bin/check_reserved_slugs` to verify.

## Style

- Rubocop Rails Omakase baseline
- `annotaterb` after every migration
- No tests in v1 (deferred). Factories are for seeds.
- Prefer boring, conventional Rails. This is a maintainable monolith, not an architecture demo.

## Design palette

- Background: warm off-white (masa, `#F7F1E8`)
- Primary: terracotta (`#A64B2A`) or mole (`#5E2A22`)
- Accent: nopal green (`#4A7C59`)
- **Never purple.** No 3D blobs. No chef hats. No gradient headers.

## Example data conventions

When creating seeds, fixtures, or placeholder content:

- Real Mexican names: Carmen, Lupita, Elena, Marisol, Mariana, Don Mario
- Real dishes: *tamal verde, pozole, enchiladas suizas, pastel de tres leches, agua de jamaica, champurrado*
- Real colonias: Condesa, Del Valle, Chapalita, San Pedro Garza García, Providencia, Zona Esmeralda
- Realistic 2026 prices: tamal $25–35, pastel $350–600, comida corrida $80–120
- Two seed accounts: *Cocina de Elena* (simple mode) and *Taquería Don Mario* (advanced mode)
