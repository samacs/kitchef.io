# Kitchef — Technical Requirements Document

**Version:** 1.0 (v1 scope)
**Owner:** Saul
**Companion doc:** `PRD.md`
**Reference implementation:** https://github.com/samacs/agendario.mx

---

## 1. Stack Summary

| Layer | Choice | Notes |
|---|---|---|
| Language | **Ruby 4.0.2** | RVM gemset `kitchef.io`; `.ruby-version` pinned |
| Framework | **Ruby on Rails 8.1.x** | native auth, Hotwire, Propshaft |
| Database | **PostgreSQL 18** | with `pgvector`, `fuzzystrmatch`, `pg_trgm`, `pg_stat_statements` |
| Cache / Queue / Cable | **Valkey 9** | wire-compatible with Redis; `redis` + `hiredis` + `hiredis-client` gems; single `config.redis_config` shared across Sidekiq, Rails.cache, Action Cable |
| Background jobs | **Sidekiq 8 + sidekiq-cron** | `bin/sidekiq -C config/sidekiq.yml` (binstub); Procfile.dev `worker:` line; schedule loads from `config/schedule.yml` when present |
| Web server | **Puma + Thruster** | SSL binding in dev via `ssl://0.0.0.0:3000?key=&cert=`; local certs in `./ssl/` generated per-machine with mkcert |
| Asset pipeline | **Propshaft + Importmap** | no Node toolchain, no ESbuild |
| CSS | **Tailwind CSS v4** | CSS-first config via `@theme` directive in `app/assets/tailwind/application.css`; tokens from `DESIGN.md`; dark mode via `.dark` class + pre-paint `theme_bootstrap.js` |
| Design primitives | **Bespoke `app/components/ui/*`** | Flowbite was dropped — `DESIGN.md` defines deep-green accent, bone background, Instrument Serif / Inter / JetBrains Mono; Flowbite defaults would fight every token |
| JS framework | **Hotwire (Turbo + Stimulus)** | plus Hotwire Spark in dev |
| View layer | **ERB + ViewComponent** | components for anything that repeats or has logic |
| Icons | **Lucide + lucide-rails helper** | custom SVG when Lucide doesn't have what we need |
| Auth | **Rails 8 native auth** | (no Devise); `app/constraints/` for routing-layer gating (UserConstraint / AdminConstraint); Omniauth for Google later |
| Email (dev) | **letter_opener_web** | mounted at `/letter_opener` in dev |
| Email (prod) | **Resend** | via `resend` gem |
| File storage | **ActiveStorage + active_storage_validations** | S3 in prod, disk in dev |
| Money | **money + money-rails** | MXN default, MXN only in UI |
| Phone | **phonelib + phony_rails** | default MX; Phonelib API exposes `strict_check=` (not `strict_validation=`) |
| Serialization | **Oj + oj_serializers** | for any JSON endpoints |
| Deployment | **Kamal + Docker** | postgres + valkey in `docker/`, custom Dockerfiles, bind-mounted init scripts |
| Code style | **rubocop-rails-omakase** | plus rails / performance / factory_bot / faker rules |
| Testing | **Skipped for v1** | FactoryBot + Faker are in the Gemfile but unused — seeds use hardcoded pools of real Mexican names (Faker's `es-MX` locale was flaky); re-wire factories when tests land |

---

## 2. Architecture Overview

Kitchef is a monolithic Rails 8 application, server-rendered with Hotwire, deployed as a single Docker container backed by PostgreSQL and Valkey. No microservices, no separate frontend, no React.

```
┌────────────────────────────────────────────────────────────────┐
│                     Browser / Mobile Web                        │
│            (Turbo + Stimulus, served ERB + VC)                 │
└─────────────────────────────┬──────────────────────────────────┘
                              │ HTTPS
┌─────────────────────────────┴──────────────────────────────────┐
│                         Thruster (HTTP)                         │
│                          Puma (Rails 8)                         │
│                                                                 │
│   Controllers → Services / Commands / Queries → Models         │
│                     ↓                                           │
│                  ViewComponent → ERB → Turbo Streams            │
└──────┬────────────────────────┬─────────────────────┬──────────┘
       │                        │                     │
   ┌───┴────┐              ┌────┴─────┐         ┌────┴─────┐
   │Postgres│              │  Valkey  │         │ Sidekiq  │
   │   18   │              │    9     │         │  Worker  │
   └────────┘              └──────────┘         └──────────┘
                                 ↑
                                 │
                          Turbo Streams
                       (ActionCable via Valkey)
```

### Request flow for a new pedido from a public storefront
1. Client POSTs to `/cocina-de-elena/orders` from the public form
2. `Storefronts::OrdersController#create` invokes `Orders::PlaceOrder` command
3. Command validates, creates the order, triggers `NewOrderNotification` via Noticed
4. Noticed broadcasts via Turbo Stream to the operator's dashboard (`broadcasts_to [account, :orders]`)
5. Noticed also enqueues a Sidekiq job to send the operator a push/email
6. Client is redirected to `/cocina-de-elena/orders/ord_xyz` (order status page)
7. Operator's already-open dashboard sees the new order slide into the `placed` column in real time

---

## 3. Multi-Tenancy Model

**One `Account` per operator.** A `User` belongs to an `Account`. Every tenant-scoped model (`Client`, `Order`, `Recipe`, `Ingredient`, etc.) has `account_id` and is scoped via a `default_scope` or (preferred) an explicit `Current.account`-based scoping in controllers.

### `Current` attributes (Rails `ActiveSupport::CurrentAttributes`)
```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :account, :user, :request_id, :user_agent, :ip_address
end
```

Set in `ApplicationController` during authentication. Scopes in models reference `Current.account` when needed, but prefer explicit `account.orders.where(...)` queries from controllers for clarity.

### Storefront identification
Public storefront requests resolve `Account` via the slug in the URL:
- `/:slug` → `Account.friendly.find(slug)` → exposed as `@storefront`
- The routing constraint rejects any slug that's in `Account::RESERVED_SLUGS` before this lookup is attempted (see §8)
- Storefront controllers do NOT set `Current.account` (no authenticated session); they set `@storefront` locally.

---

## 4. Domain Model

### Core entities

#### `User`
- `email_address`, `password_digest` (Rails 8 auth)
- `first_name`, `last_name` (via `name_of_person`)
- `phone`, `phone_normalized` (via `phony_rails`)
- `account_id` (single account in v1; `has_one :account` on user and `belongs_to :owner, class_name: "User"` on account)
- `discarded_at` (soft delete)

#### `Account`
- `name` (kitchen name: "Cocina de Elena")
- `slug` (friendly_id, e.g., "cocina-de-elena") — must pass `RESERVED_SLUGS` exclusion validation
- `prefixed_id` (prefix: `acc_`)
- `default_currency` (MXN)
- `time_zone` (America/Mexico_City default)
- `iva_enabled` (boolean, default false)
- `iva_rate_percent` (default 16)
- `public_profile` (StoreModel JSONB: description, tagline, phone, whatsapp, instagram, colonia, city, delivery_zones[], payment_methods[], accepts_orders_schedule, pickup_reminder_hours — see §4.1)
- `branding` (StoreModel JSONB: palette[bosque|terracota|tinto|cobalto|mostaza|cacao|pizarra|rosa|durazno|noroc], theme_default[auto|light|dark], hide_kitchef_branding — see §4.1)
- `settings` (StoreModel JSONB: feature flags and preferences — see below)
- `subscription_id`
- ActiveStorage: `has_one_attached :logo`, `has_one_attached :cover_photo`
- `discarded_at`

##### `Account#settings` (StoreModel)

The `settings` JSONB column holds per-account feature flags and behavioral preferences. Modeled via `store_model` so we get typed attributes and validations:

```ruby
# app/models/accounts/settings.rb
class Accounts::Settings
  include StoreModel::Model

  attribute :use_composable_recipes, :boolean, default: false
  attribute :composable_recipes_unlocked_at, :datetime
  attribute :digest_enabled, :boolean, default: true
  attribute :digest_time, :string, default: "07:00"
  attribute :onboarding_completed, :boolean, default: false
  attribute :onboarding_advanced_mode_choice, :string  # "yes" | "no" | "skip"
  attribute :show_cost_hints, :boolean, default: true
end
```

**Key flag for Module 2:** `use_composable_recipes` controls whether the UI exposes advanced recipe-decomposition controls. Default is `false`; flipped to `true` either (a) when the operator completes her first-decomposition onboarding flow, or (b) when she opts into advanced mode during initial signup. See §6 for the UI-adaptation pattern.

##### `Account#branding` (StoreModel) — storefront theme

```ruby
# app/models/accounts/branding.rb
class Accounts::Branding
  include StoreModel::Model

  PALETTES = %w[bosque terracota tinto cobalto mostaza cacao pizarra rosa durazno noroc].freeze
  THEMES   = %w[auto light dark].freeze

  attribute :palette,              :string,  default: "bosque"
  attribute :theme_default,        :string,  default: "auto"
  attribute :hide_kitchef_branding, :boolean, default: false  # Pro-only

  validates :palette,       inclusion: { in: PALETTES }
  validates :theme_default, inclusion: { in: THEMES }
end
```

Palette definitions (primary color + pre-computed `ink`/`soft`/`line` for light and dark) live in `config/palettes.yml` and are surfaced via `Storefronts::Palette.for(account)`, which renders inline CSS custom properties (`--brand-1`, `--brand-1-ink`, `--brand-1-soft`, `--brand-1-line`) into the `<body>` tag. The storefront stylesheet consumes those variables; the operator app is untouched (it always renders in the Kitchef green palette).

##### `Account#public_profile` (StoreModel) — storefront meta

```ruby
# app/models/accounts/public_profile.rb
class Accounts::PublicProfile
  include StoreModel::Model

  DESCRIPTION_MAX = 280
  FULFILLMENT = %w[pickup delivery shipping].freeze

  attribute :description,    :string,  default: ""
  attribute :tagline,        :string,  default: ""
  attribute :phone,          :string,  default: ""
  attribute :whatsapp,       :string,  default: ""
  attribute :instagram,      :string,  default: ""
  attribute :colonia,        :string,  default: ""
  attribute :city,           :string,  default: ""
  attribute :fulfillment_types, :string, default: "pickup,delivery"  # comma-separated subset of FULFILLMENT
  attribute :delivery_zones, :string, default: ""  # comma-separated colonia names (MVP; promoted to array when slot UI lands)
  attribute :payment_notes,  :string,  default: ""   # free text, shown to customer after submit ("Te contacto por WhatsApp…")
  attribute :pickup_reminder_hours, :integer, default: 4

  # Accepting-orders weekly schedule — map of day-of-week (0..6) → { open:"HH:MM", close:"HH:MM" } | "closed".
  # Storefront hero surfaces this as a live chip; submissions are still accepted
  # when closed, but customers see "Abrimos el jueves 9:00".
  attribute :ordering_hours, :string, default: ""  # JSON-encoded; lifted into OrderingHours service for parsing

  validates :description, length: { maximum: DESCRIPTION_MAX }
  validates :tagline,     length: { maximum: 80 }
  validates :pickup_reminder_hours, numericality: { in: 0..24 }
end
```

`fulfillment_types` is a flat comma-separated string (not a jsonb array) so the form can use plain `collection_check_boxes` without a StoreModel array coercion wrinkle. The values read through a `#fulfillment_type_options` helper that splits and validates against `FULFILLMENT`.

#### `Client`
- `account_id`
- `first_name`, `last_name` (name_of_person — the gem hard-requires these exact column names; can't override)
- `phone`, `phone_normalized`
- `email`
- `colonia`, `city`, `street_address`, `references_note` (how to find the house — `references` alone conflicts with AR's reflection names)
- `notes` (free text)
- `allergies` (text)
- `birthday` (date, for reminders)
- `prefixed_id` (prefix: `cli_`)
- `discarded_at`
- Versioned via `paper_trail`
- `has_many :orders, dependent: :nullify` — orders outlive clients for historical reporting

#### `Ingredient`
- `account_id`
- `name` ("masa de maíz")
- `unit` (English: `g`, `kg`, `ml`, `l`, `piece`; rendered via `t("units.*")`)
- `unit_cost_cents` (Money, default MXN)
- `price_updated_at`
- `category` (enum, English keys: `pantry`, `meats`, `dairy`, `produce`, `spices`, `other`; display via `t("ingredient.categories.*")`)
- `supplier_name` (optional)
- `notes`
- `prefixed_id` (prefix: `ing_`)
- `position` (Positioning gem, scoped to account+category)
- `discarded_at`
- Versioned via `paper_trail` — we want a history of price changes

#### `Recipe`
- `account_id`
- `name` ("Tamal verde", "Masa para tamales")
- `slug` (friendly_id, scoped to account)
- `description`
- `sale_price_cents` (Money) — meaningful only when `is_saleable` is true
- `is_saleable` (boolean) — does this recipe appear on the public menu and in orders?
  - `true` for things Elena actually sells (*Tamal verde*, *Pastel de tres leches*)
  - `false` for internal preparations (*Masa*, *Salsa verde base*, *Relleno de pollo*) used only as components of other recipes
- `yield_quantity` (decimal) — how much this recipe produces in a single batch
- `yield_unit` (string enum, English keys: `piece`, `g`, `kg`, `ml`, `l`, `serving`; display via `t("units.*")`)
  - A saleable tamal recipe might have `yield_quantity: 1, yield_unit: "piece"` (we cost per tamal)
  - An internal masa recipe might have `yield_quantity: 1800, yield_unit: "g"` (we cost per gram of masa)
  - Cost-per-yield-unit is the canonical unit cost used when this recipe is referenced as a component
- `category` (enum, English keys: `mains`, `starters`, `desserts`, `drinks`, `bases`, `other`; display via `t("recipe.categories.*")` — `t("recipe.categories.bases") → "Bases y preparaciones"`)
  - `bases` is the typical category for non-saleable internal recipes
- `target_margin_percent` (default 60) — only meaningful for saleable recipes
- `is_published` (boolean — shows on public storefront) — can only be true if `is_saleable` is also true
- `cost_cents_cached` (bigint, nullable) — fast-path cache of the fully resolved component tree cost. **`monetize :cost_cents_cached, as: :cost_cached, allow_nil: true`** — money-rails can't infer monetization from the non-standard `_cached` suffix, so alias the helper name explicitly.
- `prefixed_id` (prefix: `rec_`)
- `position` (scoped to account+category)
- `discarded_at`
- ActiveStorage: `has_many_attached :photos` (validated via active_storage_validations)
- Versioned via `paper_trail`
- **Computed**: `cost_cents`, `cost_per_yield_unit_cents`, `margin_cents`, `margin_percent` — all derived from the recipe's components
- **Validations**: `is_published` requires `is_saleable`; `sale_price_cents` required when `is_saleable` is true; `yield_quantity > 0`
- `has_many :usages, as: :componentable, dependent: :destroy` — cascades so `Account.destroy` works; the "warn operator about affected parents" UX is a controller concern, not a model-level restriction

#### `RecipeComponent` (polymorphic join replaces the old `RecipeIngredient`)

A recipe can have many components. Each component points to **either an `Ingredient` or another `Recipe`** via a polymorphic association. This is the schema that enables arbitrary decomposition depth.

- `recipe_id` — the **parent** recipe (the thing being composed)
- `componentable_type` — `"Ingredient"` or `"Recipe"` (polymorphic)
- `componentable_id` — FK to ingredient or recipe
- `quantity` (decimal)
- `unit` (string, English keys: `g`, `kg`, `ml`, `l`, `piece` — must be compatible with the target's declared units; display via `t("units.*")` → "pieza", "porción", etc.)
- `notes` (optional — "picado fino", "a temperatura ambiente")
- `position` (scoped to recipe)

**Constraints & invariants:**
- A recipe cannot be a component of itself (direct self-reference blocked at validation time)
- A recipe cannot transitively reference itself (cycle detection enforced by the `Recipes::CycleDetector` service before save; see §6)
- The `unit` on the component must be convertible to the target's canonical unit (see "Unit conversion" below)
- When a recipe references another recipe as a component, the parent always uses the child's **cost** (never its `sale_price_cents`, even if the child is also saleable)
- If an account has `use_composable_recipes: false`, the UI only allows `componentable_type == "Ingredient"` (recipes-as-components are hidden entirely); the schema still supports both types so no migration is needed when the flag flips

#### Unit conversion

Component quantities must be convertible to the target's canonical unit. The canonical unit for an ingredient is its stored `unit`; the canonical unit for a recipe-as-component is its `yield_unit`.

We maintain a static conversion table for the common cases:

| From | To | Factor |
|---|---|---|
| kg | g | × 1000 |
| l | ml | × 1000 |
| g | kg | × 0.001 |
| ml | l | × 0.001 |
| piece | piece | 1:1 only |
| serving | serving | 1:1 only |

Cross-type conversion (e.g., grams → pieces) is **not** automatic and requires the target recipe to declare both a weight yield and a piece yield. For v1, we keep this strict: if Elena's *masa* recipe yields `1800 g` but her *tamal verde* references *masa* in units of *pieza*, the cost engine raises a user-visible error: *"Tu receta de masa está en gramos pero tu tamal verde usa 'piezas'. ¿Cuántos gramos tiene una pieza de masa?"* — prompting her to either normalize the component unit or add a dual-yield declaration. This is handled in `Recipes::CostCalculator` (see §6).

#### `Order`
- `account_id`
- `client_id` (nullable — some orders come from anonymous storefront visitors before client is created; resolved in `PlaceOrder` command)
- `prefixed_id` (prefix: `ord_`)
- `state` (AASM, English keys: `placed`, `confirmed`, `in_production`, `ready`, `delivered`, `paid`, `canceled`; display via `t("order.state.*")`)
- `delivery_date` (date, required)
- `delivery_start_time`, `delivery_end_time` — **integer minutes from midnight (0..1440)**, not datetime. A delivery window is "Saturday 11am-12pm in the operator's local time", not an absolute moment. Integers avoid timezone/DST drift, make `end - start` a one-subtraction duration, and keep range queries trivial. See `lib/time_of_day.rb` for the `from_string("09:30") → 570` / `to_string(570) → "09:30"` helpers; models expose `*_hhmm` accessors for forms. DB check constraints enforce `start < end`, `0..1440`.
- `delivery_type` (enum, English keys: `delivery`, `pickup`; display via `t("order.delivery_types.*")`). *Delivery* = the kitchen takes the pedido to the customer (with geocoding for runner directions). *Pickup* = the customer comes to the kitchen.
- `delivery_address`, `colonia`, `city`
- `delivery_notes`
- `subtotal_cents`, `tax_cents`, `total_cents` (Money)
- `deposit_cents`, `balance_cents` (Money)
- `notes`
- `source` (enum: `storefront`, `manual`, `whatsapp`, `instagram`, `other` — keys already English)
- `position` (scoped to account+state, for drag-reorder within a column)
- `pickup_reminder_sent_at` (datetime, nullable) — stamped by `PickupReminderJob` (see §11) the first time a `ready` pickup pedido crosses the configured `pickup_reminder_hours` threshold. Prevents duplicate pings.
- `discarded_at`
- Versioned via `paper_trail`

#### `OrderItem`
- `order_id`
- `recipe_id` — must point to a recipe where `is_saleable: true` (enforced at validation)
- `quantity`
- `unit_price_cents` (snapshot at order time — if recipe price changes later, order keeps original price)
- `unit_cost_cents` (snapshot of fully-resolved cost at order time, including all nested recipe components)
- `notes` ("sin cilantro", "extra salsa")
- `position` (scoped to order)

#### `Payment`
- `order_id`
- `amount_cents` (Money)
- `method` (enum, English keys: `cash`, `transfer`, `card`, `mercado_pago`, `other` — `mercado_pago` stays as-is because it's the brand name; display via `t("payment.methods.*")`)
- `received_at` (datetime)
- `reference` (e.g., SPEI reference number)
- `notes`
- `prefixed_id` (prefix: `pay_`)

#### `DeliverySlot`
- `account_id`
- `day_of_week` (integer, 0–6)
- `start_time`, `end_time` — **integer minutes from midnight (0..1440)**, same pattern as `Order.delivery_*_time`. Check constraints enforce `start < end`, `0..1440`, `day_of_week BETWEEN 0 AND 6`.
- `max_orders` (integer)
- `colonias` (JSONB array of colonia names — "Condesa", "Roma Norte", etc.)
- `position`
- Used together with `interval_set` to prevent overbooking

#### `Subscription` (Stripe-backed)
- `account_id`
- `stripe_customer_id`
- `stripe_subscription_id`
- `plan` (enum, English keys: `free`, `pro`, `team` — brand names **Libreta** / **Cocina** / **Taller** rendered via `t("subscription.plans.*")`)
- `status` (enum: `trialing`, `active`, `past_due`, `canceled`, `incomplete` — keys already English)
- `trial_ends_at`
- `current_period_end`
- `cancel_at_period_end` (boolean)

#### `Notification` (via Noticed)
- Standard Noticed schema — notifications about new orders, payments received, etc.

### Entity relationship diagram (textual)

```
User ─1:1─ Account ─1:N─ Client
                 ├─1:N─ Ingredient ──────────┐
                 ├─1:N─ Recipe ─1:N─ RecipeComponent (polymorphic)
                 │          └─1:N─ RecipeComponent ──► Ingredient OR Recipe
                 │          (recipe can be composed of ingredients
                 │           AND/OR other recipes, arbitrarily deep)
                 ├─1:N─ Order ─N:1─ Client
                 │           └─1:N─ OrderItem ─N:1─ Recipe (is_saleable: true only)
                 │           └─1:N─ Payment
                 ├─1:N─ DeliverySlot
                 └─1:1─ Subscription
```

### The recipe graph — worked example

Here's what Elena's recipe graph looks like once she's fully decomposed her *tamal verde*:

```
Tamal verde (saleable, $25 MXN, yield: 1 pieza)
├── Masa (internal recipe, yield: 1800 g)
│   ├── Harina de maíz nixtamalizada (ingredient, 1 kg @ $24/kg)
│   ├── Manteca de cerdo (ingredient, 300 g @ $85/kg)
│   ├── Polvo para hornear (ingredient, 15 g @ $120/kg)
│   ├── Sal (ingredient, 10 g @ $15/kg)
│   └── Caldo de pollo (ingredient, 800 ml @ $18/l)
├── Relleno de pollo (internal recipe, yield: 500 g)
│   ├── Pechuga de pollo (ingredient, 400 g @ $145/kg)
│   ├── Salsa verde (internal recipe, yield: 300 ml)
│   │   ├── Tomate verde (ingredient, 500 g @ $28/kg)
│   │   ├── Chile serrano (ingredient, 30 g @ $60/kg)
│   │   ├── Cebolla (ingredient, 50 g @ $22/kg)
│   │   └── Cilantro (ingredient, 10 g @ $80/kg)
│   └── Cebolla (ingredient, 30 g @ $22/kg)
└── Hoja de maíz (ingredient, 1 pieza @ $0.80/pieza)
```

The cost engine resolves this bottom-up: each ingredient contributes its per-unit cost, each internal recipe's cost-per-yield-unit is computed from its components, and the saleable tamal's final cost is the sum of its resolved components. A price change on corn flour invalidates the cached cost of *Masa*, which invalidates *Tamal verde*, which updates the dashboard margin flag. See `Recipes::CostCalculator` in §6.

---

## 5. Key Design Patterns

### Service / Command / Query trinity

The Agendario Gemfile references both `light-service` (for pipeline-style multi-step workflows) and implicit POROs. For Kitchef:

- **`ApplicationService`** — POROs with `.call` class method, for any non-trivial business logic that doesn't fit cleanly in a model. Used for read operations that need coordination.
- **`ApplicationCommand`** — write-side operations: create / update / state-transition. One command per business action. Returns a `Result` object with `.success?`, `.failure?`, `.object`, `.errors`.
- **`ApplicationQuery`** — read-side, database-heavy operations: menu engineering matrix, production planning rollup, finance reports. Returns structs, not AR objects, when denormalized.
- **`light-service`** — for genuinely multi-step workflows (e.g., `Onboarding::BootstrapKitchen` that creates account + sample recipes + sample ingredients + first subscription). Skip for simple cases.

#### Base classes

```ruby
# app/services/application_service.rb
class ApplicationService
  extend Dry::Initializer

  def self.call(...)
    new(...).call
  end

  def call
    raise NotImplementedError
  end
end
```

```ruby
# app/commands/application_command.rb
class ApplicationCommand
  extend Dry::Initializer

  Result = Data.define(:success, :object, :errors) do
    def success? = success
    def failure? = !success
  end

  def self.call(...)
    new(...).call
  end

  def call
    raise NotImplementedError
  end

  private

  def success(object) = Result.new(success: true, object:, errors: nil)
  def failure(errors) = Result.new(success: false, object: nil, errors:)
end
```

```ruby
# app/queries/application_query.rb
class ApplicationQuery
  extend Dry::Initializer

  def self.call(...)
    new(...).call
  end

  def call
    raise NotImplementedError
  end
end
```

#### Naming convention

- Commands live under `app/commands/<domain>/<verb>.rb`
  - `Orders::PlaceOrder`
  - `Orders::ConfirmOrder`
  - `Orders::MarkAsDelivered`
  - `Recipes::UpdateCostSnapshot`
  - `Recipes::Decompose` — first-time decomposition of a saleable recipe; flips `use_composable_recipes` if currently false
  - `Recipes::AddComponent` — adds an `Ingredient` or `Recipe` as a component
  - `Recipes::ConvertToInternal` — marks a saleable recipe as internal (warns if used by saleable parents)
  - `Recipes::PromoteToSaleable` — promotes an internal recipe to saleable (requires sale_price)
  - `Ingredients::UpdatePrice` — updates ingredient price and invalidates all dependent recipe cost caches
- Services live under `app/services/<domain>/<noun>.rb`
  - `Billing::StripeCustomerSync`
  - `Storefronts::ResolveBySlug`
  - `Recipes::CostCalculator` — pure function: given a recipe, resolves the full component tree and returns total cost; uses memoization within a single resolve call
  - `Recipes::CycleDetector` — validates that adding a component won't introduce a cycle; runs in `RecipeComponent` before_save
  - `Recipes::DependencyGraph` — given an ingredient or recipe, returns all recipes that depend on it (directly or transitively); used when invalidating caches on price updates
- Queries live under `app/queries/<domain>/<noun>.rb`
  - `Reports::MenuEngineeringMatrix`
  - `Reports::IngredientImpactAnalysis` — ranks ingredients by total monthly consumption cost across all recipes (advanced-mode only)
  - `Production::WeeklyShoppingList` — flattens nested recipes into a raw-ingredient shopping list for the week's orders
  - `Finance::MonthlyMargins`

### ViewComponent conventions
- Use a component **whenever logic appears in a template** or **whenever a partial is rendered from more than one place**.
- Component files live under `app/components/<domain>/<noun>_component.rb` with a sidecar ERB template.
- Components for UI primitives (button, card, badge) live under `app/components/ui/`.
- UI primitives render design tokens from `app/assets/tailwind/application.css` (the `@theme` block) — no raw hex colors, no utility-class soup outside the UI primitives themselves. Flowbite was evaluated and dropped — see §16.

Example:

```ruby
# app/components/orders/card_component.rb
class Orders::CardComponent < ViewComponent::Base
  extend Dry::Initializer

  option :order
  option :compact, default: -> { false }

  delegate :client, :delivery_date, :total, to: :order

  def state_badge
    render Ui::BadgeComponent.new(variant: state_variant, label: I18n.t("orders.state.#{order.state}"))
  end

  private

  def state_variant
    { pedido: :warning, confirmado: :info, en_produccion: :primary,
      listo: :success, entregado: :success, pagado: :success,
      cancelado: :neutral }.fetch(order.state.to_sym)
  end
end
```

### Decent Exposure convention
- Use `expose :order` in controllers to reduce instance-variable boilerplate.
- Memoized by default, so complex expressions are safe.
- Example:

```ruby
class OrdersController < ApplicationController
  expose :orders, -> { Current.account.orders.kept.order(delivery_date: :asc) }
  expose :order, -> { orders.find_by_prefix_id(params[:id]) || Current.account.orders.build }

  def update
    result = Orders::UpdateOrder.call(order:, attributes: order_params)
    redirect_to orders_path, notice: result.success? ? "Pedido actualizado." : "Error: #{result.errors.to_sentence}"
  end
end
```

### Turbo Stream / real-time conventions
- Every model that appears on a dashboard broadcasts to its account channel.
- `Order` broadcasts to `[account, :orders]`. When it moves state, the target frame moves columns via `turbo_stream.replace`.
- Use `broadcast_refreshes` for simple cases; switch to explicit `after_create_commit -> { broadcast_append_to ... }` when granular control is needed.
- Public storefront views do NOT broadcast (no open stream; customers visit once).
- **Controllers that forms redirect to MUST return HTML.** Turbo Drive silently bails on `text/plain` responses after a form submit — the DOM doesn't swap and the flow looks broken. `ApplicationController#render_stub(title:, meta:)` renders `app/views/shared/stub.html.erb` with the right content type for Phase 6 placeholders.

### Routing-layer constraints (`app/constraints/`)

Three classes, mirroring Agendario's pattern:

- `ApplicationConstraint` — base. Takes the request in initializer, dispatches class-level `.matches?` to instance `#authorized?`.
- `UserConstraint < ApplicationConstraint` — builds a `CookieJar` from the request, reads `:session_id` via `cookies.signed`, resolves to a `User`. `authorized?` returns `user.present?`.
- `AdminConstraint < UserConstraint` — `super && user.admin?`.

Used sparingly — only where routing has to pick between **different controllers for the same URL**:

```ruby
# Root: signed-in operators get their dashboard; everyone else sees marketing
root "dashboards#show", constraints: UserConstraint, as: :authenticated_root
root "static_pages#show", defaults: { page: "home" }

# Platform admin: non-admins fall through → storefront rejects "admin" → 404
constraints AdminConstraint do
  namespace :admin do
    root "dashboards#show"
  end
end
```

For the operator app (`/orders`, `/recipes`, etc.) **we don't use constraints**. Controller-level `require_authentication` (from the Rails 8 `Authentication` concern) redirects unauth'd requests to `/sign-in` and preserves `return_to_after_authenticating` in the session — which gets the operator back to where they were after signing in. A routing constraint would lose that return-to context.

---

## 6. Composable Recipes Architecture

This section is the technical counterpart to PRD Module 2. The feature ships in v1 with the adaptive-UI pattern described in the PRD.

### 6.1 — The cost calculator algorithm

`Recipes::CostCalculator` is a pure service that resolves a recipe's full component tree and returns its total cost. It's memoized per-call (not globally) to handle diamond dependencies — e.g., two recipes in a tree that both reference the same *salsa verde*, which should be computed once per resolve.

```ruby
# app/services/recipes/cost_calculator.rb
class Recipes::CostCalculator < ApplicationService
  option :recipe
  option :memo, default: -> { {} }
  option :visited, default: -> { Set.new }

  def call
    resolve(recipe)
  end

  private

  def resolve(node)
    # Memoization within this resolve call
    return memo[node.id] if memo.key?(node.id)

    # Cycle detection at calculation time (defense-in-depth;
    # also enforced at save time by CycleDetector)
    if visited.include?(node.id)
      raise Recipes::CycleError, "Ciclo detectado en la receta #{node.name}"
    end

    visited.add(node.id)

    total_cents = node.components.sum do |component|
      component_unit_cost_cents(component) * quantity_in_target_unit(component)
    end

    visited.delete(node.id)
    memo[node.id] = total_cents

    total_cents
  end

  def component_unit_cost_cents(component)
    case component.componentable
    when Ingredient
      component.componentable.unit_cost_cents
    when Recipe
      # Recursive: resolve the sub-recipe's cost, then divide by its yield
      sub_recipe = component.componentable
      sub_total = resolve(sub_recipe)
      (sub_total.to_d / sub_recipe.yield_quantity).to_i
    end
  end

  def quantity_in_target_unit(component)
    # Converts component.quantity (expressed in component.unit)
    # into the target's canonical unit (ingredient.unit or recipe.yield_unit)
    Recipes::UnitConverter.call(
      quantity: component.quantity,
      from_unit: component.unit,
      to_unit: canonical_unit_for(component.componentable)
    )
  end

  def canonical_unit_for(thing)
    thing.is_a?(Ingredient) ? thing.unit : thing.yield_unit
  end
end
```

**Properties worth noting:**
- The algorithm is O(n) in the number of nodes, not O(n²), because of per-call memoization
- Cycle detection at calculation time is defense-in-depth; the primary guard is `Recipes::CycleDetector` at save time
- Cost is always returned in integer cents (MXN); fractional cents are truncated, not rounded — consistent with how `money-rails` handles sub-cent precision
- A `Recipes::UnitConversionError` is raised with a user-friendly Spanish message when an incompatible unit pairing is encountered; controllers catch and surface these in the UI

### 6.2 — Cycle detection at save time

`Recipes::CycleDetector` runs in a `before_save` on `RecipeComponent`. It's a breadth-first traversal from the proposed child back toward potential ancestors, checking whether the parent appears as a descendant of the component being added.

```ruby
# app/services/recipes/cycle_detector.rb
class Recipes::CycleDetector < ApplicationService
  option :parent_recipe
  option :proposed_component

  def call
    return true if proposed_component.is_a?(Ingredient)

    # Walk the proposed component's full descendant tree
    # If we ever encounter parent_recipe, it's a cycle
    queue = [proposed_component]
    visited = Set.new

    while (current = queue.shift)
      return false if current.id == parent_recipe.id
      next if visited.include?(current.id)

      visited.add(current.id)

      current.components.each do |child_component|
        if child_component.componentable.is_a?(Recipe)
          queue.push(child_component.componentable)
        end
      end
    end

    true
  end
end
```

Used as a validator on the join model:

```ruby
# app/models/recipe_component.rb
class RecipeComponent < ApplicationRecord
  belongs_to :recipe
  belongs_to :componentable, polymorphic: true

  validate :no_cycles

  private

  def no_cycles
    return unless componentable.is_a?(Recipe)

    unless Recipes::CycleDetector.call(
      parent_recipe: recipe,
      proposed_component: componentable
    )
      errors.add(:componentable, "crearía un ciclo: esta receta ya depende de sí misma")
    end
  end
end
```

### 6.3 — Cache invalidation on price changes

When an ingredient's price changes — or when any recipe's components change — every recipe that depends on it (directly or transitively) needs its cached cost recomputed. This is an async operation to keep ingredient-price-edit UX snappy.

```ruby
# app/services/recipes/dependency_graph.rb
# Given an ingredient or recipe, returns all recipes that depend on it.
class Recipes::DependencyGraph < ApplicationService
  option :node  # Ingredient or Recipe

  def call
    # Find direct parents
    direct_parents = Recipe
      .joins(:components)
      .where(recipe_components: {
        componentable_type: node.class.name,
        componentable_id: node.id
      })
      .distinct

    # Transitive closure via recursive CTE
    Recipe.find_by_sql([<<~SQL, node.class.name, node.id])
      WITH RECURSIVE ancestors AS (
        SELECT r.id, r.account_id
        FROM recipes r
        JOIN recipe_components rc ON rc.recipe_id = r.id
        WHERE rc.componentable_type = ? AND rc.componentable_id = ?

        UNION

        SELECT r.id, r.account_id
        FROM recipes r
        JOIN recipe_components rc ON rc.recipe_id = r.id
        JOIN ancestors a ON rc.componentable_type = 'Recipe'
                        AND rc.componentable_id = a.id
      )
      SELECT DISTINCT r.* FROM recipes r
      JOIN ancestors a ON r.id = a.id
      WHERE r.discarded_at IS NULL
    SQL
  end
end
```

On price change:

```ruby
# app/commands/ingredients/update_price.rb
class Ingredients::UpdatePrice < ApplicationCommand
  option :ingredient
  option :unit_cost_cents

  def call
    ingredient.update!(
      unit_cost_cents: unit_cost_cents,
      price_updated_at: Time.current
    )

    # Find all recipes that depend on this ingredient
    dependents = Recipes::DependencyGraph.call(node: ingredient)

    # Enqueue cost recalc + broadcast for each
    dependents.find_each do |recipe|
      Recipes::UpdateCostSnapshotJob.perform_later(recipe_id: recipe.id)
    end

    success(ingredient)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  end
end
```

`Recipes::UpdateCostSnapshotJob` calls `CostCalculator`, writes the result to `recipe.cost_cents_cached` (a column on `recipes` we maintain for fast dashboard reads), and broadcasts a Turbo Stream update to any operator currently viewing the recipes list.

**Why cache at all?** The menu-engineering dashboard needs to render 10–40 recipes quickly, and recomputing each one's full tree on every page load would be wasteful. The cache is eventually consistent: the `cost_cents_cached` column is what we display; the live `CostCalculator` is what we use when the operator opens a recipe detail page and needs ground truth.

### 6.4 — UI adaptation pattern

The UI behaves differently based on `Current.account.settings.use_composable_recipes?`. This gets checked in three layers:

**1. ViewComponent level** — the form component for creating or editing a recipe renders different fields:

```ruby
# app/components/recipes/form_component.rb
class Recipes::FormComponent < ApplicationComponent
  option :recipe
  option :account

  def composable_mode?
    account.settings.use_composable_recipes?
  end

  def component_picker_options
    return Ingredient.kept.where(account_id: account.id) unless composable_mode?

    # In advanced mode, components can be ingredients OR other recipes
    {
      ingredients: Ingredient.kept.where(account_id: account.id),
      recipes: Recipe.kept.where(account_id: account.id).where.not(id: recipe.id)
    }
  end
end
```

The ERB template then conditionally renders either a simple ingredient-only picker or a tabbed picker with *Ingredientes* / *Recetas* tabs.

**2. Stimulus controller level** — client-side form behaviors that only apply in advanced mode:

```javascript
// app/javascript/controllers/recipe_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["componentTypeSelector", "yieldFields", "saleableToggle"]
  static values = { composable: Boolean }

  connect() {
    if (!this.composableValue) {
      this.hideAdvancedFields()
    }
  }

  hideAdvancedFields() {
    // Hide the "internal recipe" option (is_saleable: false)
    // Hide the recipe-picker tab
    // Hide the yield declaration fields (simple mode assumes yield_quantity: 1, yield_unit: "serving")
    this.componentTypeSelectorTargets.forEach(el => el.hidden = true)
    this.yieldFieldsTarget.hidden = true
    this.saleableToggleTarget.hidden = true
  }
}
```

**3. Controller level** — `before_action` guards on advanced-only actions:

```ruby
# app/controllers/recipes_controller.rb
class RecipesController < AuthenticatedController
  before_action :require_composable_mode, only: %i[decompose convert_to_internal]

  # ...

  private

  def require_composable_mode
    unless Current.account.settings.use_composable_recipes?
      redirect_to onboarding_decomposition_path(params[:id]),
                  notice: t("recipes.decompose.first_time_required")
    end
  end
end
```

### 6.5 — The onboarding decomposition flow

The first-time decomposition is a focused, 3-step form — not a settings toggle. It lives at `/onboarding/recipes/:recipe_id` and walks Elena through converting one flat recipe into a decomposed one.

**Step 1 — Picking the components** (`Onboarding::DecompositionController#show`):
- The form asks: *"¿Qué ingredientes usas para hacer este platillo?"*
- Empty repeater with *Agregar ingrediente* — free-text name + current price + unit
- No cost calculation shown yet; just capture the raw list
- Ingredients created here are added to the operator's `Ingredient` library, not just this recipe

**Step 2 — Quantities per portion**:
- For each ingredient added, the form asks: *"¿Cuánto de [masa] usas para un tamal?"*
- Operator enters a number + unit (500 g, 2 piezas, 30 ml)
- Live preview of the calculated cost appears at the bottom: *"Tu tamal cuesta $8.40 por pieza"*

**Step 3 — The reveal**:
- The full cost-vs-price comparison: *"Tu tamal te cuesta $8.40. Lo vendes en $25. Tu margen es 66% 🎉"*
- CTA: *"¡Listo! Ahora puedes descomponer tus otras recetas."*
- On submit, the `Onboarding::CompleteFirstDecomposition` command runs:

```ruby
# app/commands/onboarding/complete_first_decomposition.rb
class Onboarding::CompleteFirstDecomposition < ApplicationCommand
  option :account
  option :recipe
  option :components_data  # array of { ingredient_attrs:, quantity:, unit: }

  def call
    ActiveRecord::Base.transaction do
      components_data.each do |data|
        ingredient = account.ingredients.find_or_create_by!(name: data[:ingredient_attrs][:name]) do |ing|
          ing.assign_attributes(data[:ingredient_attrs])
        end

        recipe.components.create!(
          componentable: ingredient,
          quantity: data[:quantity],
          unit: data[:unit]
        )
      end

      # Flip the flag — this is the moment simple mode becomes advanced mode
      account.settings.use_composable_recipes = true
      account.settings.composable_recipes_unlocked_at = Time.current
      account.save!

      # Cache the initial cost
      Recipes::UpdateCostSnapshotJob.perform_later(recipe_id: recipe.id)
    end

    success(recipe)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  end
end
```

After this runs, the operator returns to `/recipes` and the UI has silently transformed — *Descomponer* actions appear on every other recipe card, a new "Recetas internas" tab appears in the top nav of the recipe section, and the menu-engineering dashboard becomes available.

### 6.6 — Order item cost snapshots with nested resolution

When an order item is created, we snapshot the full resolved cost at that moment — not just the direct ingredient cost. If Elena raises the price of corn flour tomorrow, the orders placed today keep the old cost for accurate historical margin reports.

```ruby
# app/commands/orders/add_item.rb
class Orders::AddItem < ApplicationCommand
  option :order
  option :recipe
  option :quantity
  option :notes, default: -> { nil }

  def call
    return failure(["Esta receta no está a la venta"]) unless recipe.is_saleable?

    item = order.items.create!(
      recipe: recipe,
      quantity: quantity,
      unit_price_cents: recipe.sale_price_cents,
      unit_cost_cents: Recipes::CostCalculator.call(recipe: recipe),  # full-tree resolution
      notes: notes
    )

    Orders::RecalculateTotals.call(order: order)
    success(item)
  end
end
```

This is the single point where "advanced mode" and "simple mode" converge — regardless of whether the recipe has 0 components, 3 components, or a 4-level-deep tree of sub-recipes, the order item stores the same `unit_cost_cents`. Reports don't care about the mode; they just read `order_items.unit_cost_cents` and `order_items.unit_price_cents`.

### 6.7 — What could go wrong, and the guardrails

Composable recipes add real complexity. The guardrails:

- **Cycles** — prevented at save time (`CycleDetector`), detected at calculation time (`CostCalculator`), surfaced as user-friendly errors in Spanish
- **Unit incompatibility** — strict validation at `RecipeComponent` save time; no silent conversions
- **Orphaned internal recipes** — if an operator converts a saleable recipe to internal (`ConvertToInternal`), she's warned if it's currently on active orders; if she converts an internal recipe with no saleable parents, a prompt asks *"¿Estás segura? Esta receta no está siendo usada en ningún platillo"*
- **Deleting a recipe that's used as a component** — blocked with a message listing the parent recipes: *"No se puede eliminar: esta receta se usa en Tamal verde y Tamal rojo. Elimínala primero de esas recetas."*
- **Deleting an ingredient that's used in recipes** — same pattern
- **Performance on deep trees** — practical limit is 5–6 levels (nobody builds deeper than *salsa → jitomate asado → jitomate + sal*); `CostCalculator` uses per-call memoization; `cost_cents_cached` is the fast path for dashboard rendering
- **The mode flip is one-way in v1** — once `use_composable_recipes` is true, it stays true. No un-flip. (Rationale: the moment she has even one decomposed recipe, reverting would orphan it. An explicit "Simplificar mi cocina" action could be added later if operators ask.)

---

## 7. Authentication & Authorization

### Authentication (v1)
- **Rails 8 native auth** (`rails generate authentication`) — `Session`, `User`, `PasswordsController`, `SessionsController`
- Email + password only for v1
- Password reset via Resend email in prod, `letter_opener_web` in dev
- "Remember me" via long-lived session cookie

### OAuth (planned for v1.1)
- Google OAuth via `omniauth-google-oauth2` + `omniauth-rails_csrf_protection`
- Facebook / Twitter kept in reference Gemfile but **not exposed in v1**

### Authorization
- **No Pundit/CanCan for v1.** The app is single-operator, single-account. We enforce ownership via `Current.account.orders.find(id)` pattern rather than policy objects.
- When the fonda tier introduces multi-employee teams, revisit with Pundit.

### Rate limiting & security
- `rack-attack` configured for login attempts (5/minute/IP), storefront POSTs (10/minute/IP), and password reset (3/hour/email)
- `rack-cors` scoped to our domain only
- CSP configured in `config/initializers/content_security_policy.rb`
- `brakeman` runs in CI

---

## 8. Routing

### Guiding principles
- **URL paths are English.** Brand-coherent, future-proof when we add language toggles, and matches the code-stays-English rule. Spanish lives in view copy, not URLs.
- **Root-level storefront slugs.** Public storefronts at `kitchef.mx/cocina-de-elena`, never `kitchef.mx/c/cocina-de-elena`.
- **Constraint-based root dispatch.** Signed-in operators land on their dashboard at `/`; anonymous visitors see marketing — same URL, two handlers picked by `UserConstraint`.
- **No `/panel` prefix, no `Panel::` namespace.** Operator controllers sit flat at the top level; domain sub-surfaces (`Production::`, `Reports::`, `Onboarding::`) keep URL grouping.

### Reserved top-level paths

Because public storefronts live at the **root level** (e.g., `kitchef.mx/cocina-de-elena`), every current and future top-level route must be protected from being claimed as an account slug. This is a known, managed cost of root-level slugs — the approach Agendario already uses in production without incident.

`Account::RESERVED_SLUGS` in `app/models/account.rb` is **194 entries** grouped by intent (alphabetized per block for diff-friendly growth):

1. **Kitchef app routes (Spanish — defense in depth)** — `acerca`, `ajustes`, `asistencia`, `ayuda`, `cocina`, `contacto`, `cartas` (historic), `entrar`, `pedidos`, `recetario`, `ingredientes`, `entregas`, `registro`, `recuperar`, `salir`, `sesion`, `precios`, etc. Kept even after the English path migration so operators can never use these words as slugs.
2. **English app routes** — `sign-in`, `sign-up`, `sign-out`, `reset-password`, `orders`, `clients`, `recipes`, `ingredients`, `delivery-slots`, `production`, `reports`, `subscription`, `account`, `admin`, `onboarding`, `pricing`, `how-it-works`, `faq`, `legal`, etc.
3. **Cooking-domain terms (both languages)** — `chef`, `cocinera`, `kitchen`, `restaurant`, `menu`, `meal`, `recipe`, `platillo`, `tamales`, `delivery`, `food`, etc. Operators will reflexively reach for these.
4. **Common SaaS / auth / billing paths** — `dashboard`, `settings`, `billing`, `login`, `logout`, `help`, `support`, `terms`, `privacy`, `docs`, `api`, `integrations`, etc.
5. **Tech / protocol paths** — `robots`, `sitemap`, `favicon`, `webhooks`, `oauth`, `oauth2`, `graphql`, `feed`, `rss`, `atom`, `www`, `mail`, `cable`, `recede_historical_location` (Turbo), etc.
6. **Brand names** — `kitchef`, `kitchef-mx`, `kitchef-io`, `agendario`.

**The list is expected to grow.** Any new top-level route added to `config/routes.rb` must also be added to `RESERVED_SLUGS`. The CI script at `bin/check_reserved_slugs` parses the actual route table at boot and fails the build on any missing entry. See §23.

Validated in `Account` model with I18n-keyed error messages:

```ruby
validates :slug,
  presence: true,
  uniqueness: true,
  length: { minimum: 3, maximum: 50 },
  format:     { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: :slug_format },
  exclusion:  { in: RESERVED_SLUGS,                    message: :slug_reserved }
# config/locales/es-MX/errors.yml → "no está disponible, prueba con otro nombre"
```

Storefront slugs are lowercase, hyphen-separated, ASCII only. `friendly_id` handles diacritics (*Cocina de María* → `cocina-de-maria`).

### Routing-layer constraints — `app/constraints/`

Mirrors Agendario's pattern. Three classes:

```ruby
# app/constraints/application_constraint.rb
class ApplicationConstraint
  attr_reader :request
  def initialize(request) = @request = request
  def self.matches?(request) = new(request).authorized?
  def authorized? = raise NotImplementedError
end

# app/constraints/user_constraint.rb — any signed-in user
class UserConstraint < ApplicationConstraint
  attr_reader :user, :cookies
  def initialize(request)
    super
    @cookies = ActionDispatch::Cookies::CookieJar.build(request, request.cookies)
    @user    = Session.find_by(id: cookies.signed[:session_id])&.user
  end
  def authorized? = user.present?
end

# app/constraints/admin_constraint.rb
class AdminConstraint < UserConstraint
  def authorized? = super && user.admin?
end
```

Constraints are used sparingly — only where routing must pick between **different controllers** for the same URL. For the operator app, controller-level `require_authentication` (from the Rails 8 `Authentication` concern, included in `ApplicationController`) is what handles redirects and preserves `return_to_after_authenticating`.

### Route structure

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Ops / health
  get "up" => "rails/health#show", as: :rails_health_check
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Authentication (Rails 8 native) — GET + POST on the same URL per form
  get    "/sign-in",                   to: "sessions#new",      as: :new_session
  post   "/sign-in",                   to: "sessions#create",   as: :session
  delete "/sign-out",                  to: "sessions#destroy",  as: :destroy_session

  get    "/sign-up",                   to: "registrations#new", as: :new_registration
  post   "/sign-up",                   to: "registrations#create", as: :registration

  get    "/reset-password",            to: "passwords#new",     as: :new_password
  post   "/reset-password",            to: "passwords#create",  as: :passwords
  get    "/reset-password/:token/edit", to: "passwords#edit",   as: :edit_password
  match  "/reset-password/:token",     to: "passwords#update",  as: :password, via: %i[patch put]

  # Marketing / public static pages (StaticPagesController pattern — one
  # action, view selected via :page route default, HTTP-cached)
  get "/pricing",       to: "static_pages#show", defaults: { page: "pricing" }
  get "/how-it-works",  to: "static_pages#show", defaults: { page: "how_it_works" }
  get "/faq",           to: "static_pages#show", defaults: { page: "faq" }
  get "/legal/:doc",    to: "static_pages#show", defaults: { page: "legal" }, as: :legal

  # Root — constraint-based dispatch
  root "dashboards#show", constraints: UserConstraint, as: :authenticated_root
  root "static_pages#show", defaults: { page: "home" }

  # Platform admin (Kitchef team only) — AdminConstraint gates at routing
  constraints AdminConstraint do
    namespace :admin do
      root "dashboards#show"
    end
  end

  # Authenticated operator app — flat, no /panel prefix, no Panel:: namespace
  resources :orders
  resources :clients
  resources :recipes
  resources :ingredients
  resources :delivery_slots, path: "delivery-slots"

  namespace :production do
    get "/",               to: "weekly#show",         as: :weekly
    get "/shopping-list",  to: "shopping_lists#show", as: :shopping_list
  end
  namespace :reports do
    get "/menu",     to: "menu_engineering#show", as: :menu_engineering
    get "/finance",  to: "finance#show",          as: :finance
  end
  namespace :onboarding do
    get  "/recipes/:recipe_id", to: "decomposition#show", as: :decomposition
    post "/recipes/:recipe_id", to: "decomposition#create"
  end

  resource :account,      only: %i[show edit update]
  resource :subscription, only: %i[show new create destroy]

  # Webhooks
  scope :webhooks, module: "webhooks", as: "webhooks" do
    post "/stripe", to: "stripe#create", as: :stripe
  end

  # Public storefronts — MUST stay last
  scope ":slug",
    constraints: ->(req) { !Account::RESERVED_SLUGS.include?(req.params[:slug]) },
    as: :storefront do
    get "/",     to: "storefronts#show"
    get "/menu", to: "storefronts/menus#show", as: :menu
    resources :orders, only: %i[new create show], controller: "storefronts/orders"
  end
end
```

### Controller base classes

| Base | Purpose |
|---|---|
| `ApplicationController` | Includes `Authentication` concern, sets `Current.account`, exposes `render_stub` helper |
| `AuthenticatedController` | All top-level operator controllers (orders, clients, recipes, ingredients, delivery-slots, account, subscription, dashboards). `layout "panel"`, `require_account` |
| `Storefronts::BaseController` | Public storefront surface; resolves `@storefront`, catches `RecordNotFound` → branded 404 |
| `Webhooks::BaseController` | `< ActionController::API` — no CSRF, no cookies, no view lookup |
| `Admin::BaseController` | Platform admin; layout + `require_admin` belt-and-suspenders |

Nested namespace controllers (`Production::WeeklyController`, `Reports::MenuEngineeringController`, `Onboarding::DecompositionController`) also inherit from `AuthenticatedController`.

### Static pages (marketing surface)

`StaticPagesController#show` renders a template matching `params[:page]` (or nested under `params[:doc]` for `/legal/*`). This is the Agendario pattern: adding a new marketing page = add a view file + one line in `config/routes.rb`. The controller handles HTTP caching per auth state:

```ruby
response.headers["Vary"] = "Cookie"
if authenticated?
  expires_in 0, public: false, must_revalidate: true
else
  expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
end
render page_view if stale?(etag: [ page_view, authenticated? ])
```

ETag includes auth state so the same page doesn't serve the operator's signed-in nav to anonymous visitors.

### Why this routing order is safe

1. All named routes (`/sign-in`, `/orders`, `/admin`, `/webhooks/*`, marketing) are declared **before** the catch-all storefront scope.
2. The storefront scope's lambda constraint rejects any slug in `Account::RESERVED_SLUGS` — even if a user's slug slipped past model validation somehow, Rails 404s rather than dispatching to the wrong controller.
3. The `RESERVED_SLUGS` model-level exclusion validation prevents the slug from being saved in the first place.
4. `bin/check_reserved_slugs` fails CI on any new top-level route that isn't in the list.
5. `UserConstraint` and `AdminConstraint` gate `/` and `/admin` by auth state — same URLs, different controllers, no leakage.

### URL examples

- `kitchef.mx` — marketing homepage (anonymous) OR operator dashboard (signed-in)
- `kitchef.mx/pricing`, `/how-it-works`, `/faq`, `/legal/terms` — marketing
- `kitchef.mx/sign-in`, `/sign-up`, `/reset-password` — auth
- `kitchef.mx/orders`, `/recipes`, `/delivery-slots` — operator app (signed-in)
- `kitchef.mx/production`, `/reports/menu` — operator sub-surfaces
- `kitchef.mx/admin` — platform admin (Kitchef team only)
- `kitchef.mx/cocina-de-elena` — Elena's public storefront
- `kitchef.mx/cocina-de-elena/orders/new` — order form on Elena's storefront
- `kitchef.mx/cocina-de-elena/orders/ord_abc123xyz` — order status page

---

## 8.1 Storefront theming & branded palettes

Every account ships with `Accounts::Branding` that declares a palette + theme default. `Storefronts::Palette` is the single source of truth for palette → CSS-custom-property mapping. Storefront views render palette variables inline on `<body>` so the theme survives the turbo-drive navigation without a full reload; the operator app never sees branded variables.

```ruby
# app/services/storefronts/palette.rb
class Storefronts::Palette
  PALETTES = {
    "bosque"    => { label: "Bosque",       light: { c: "#0A5A3C", ink: "#F8F6F1", soft: "#E3EDE6", line: "#B9D4C2" }, dark: { c: "#3FAE7D", ink: "#0E1714", soft: "#13382A", line: "#1F4A37" } },
    "terracota" => { label: "Terracota",    light: { c: "#B04E0E", ink: "#FFF6ED", soft: "#F6E2CB", line: "#E6C5A1" }, dark: { c: "#E08A4F", ink: "#1A0E05", soft: "#3E230F", line: "#5A3516" } },
    # … 8 more palettes mirroring the design prototype …
  }.freeze

  def self.css_vars_for(account, dark: false)
    p = PALETTES.fetch(account.branding.palette, PALETTES.fetch("bosque"))
    variant = p.fetch(dark ? :dark : :light)
    "--brand-1:#{variant[:c]};--brand-1-ink:#{variant[:ink]};--brand-1-soft:#{variant[:soft]};--brand-1-line:#{variant[:line]};"
  end
end
```

The storefront layout reads both the light and dark variant and renders both via a `<style>` block so the customer's own theme toggle flips without a server round-trip:

```erb
<style>
  :root { <%= Storefronts::Palette.css_vars_for(@storefront, dark: false) %> }
  .dark { <%= Storefronts::Palette.css_vars_for(@storefront, dark: true) %> }
</style>
```

The operator's choice (`branding.theme_default`) seeds the pre-paint boot script's default, but the customer can toggle; the result persists to `localStorage` keyed by storefront slug.

## 8.2 Guest ordering & phone-based client dedup

Storefront checkout never creates a `User`. The customer drops a pedido by filling name + phone only; `Storefronts::PlaceOrder` normalizes the phone via `Phone::NormalizeMx`, calls `Client.find_or_create_by_phone!(account:, phone:, attrs: …)`, then hands off to `Orders::Place` with the resolved `client_id` and `source: :storefront`. If the phone belongs to an existing client, the command **never overwrites** a populated name — but it backfills blank `first_name`/`last_name` so the operator's roster stays useful.

The per-order confirmation URL (`/:slug/orders/:prefixed_id`) is the access token; the prefixed_id's ~44 bits of entropy are enough to be unguessable, and `rack-attack` rate-limits the page to blunt enumeration attempts.

## 9. Billing — Stripe Subscription Flow

### Plans (internal keys are English; display labels rendered via I18n)

| Enum key | Display | Billing | Notes |
|---|---|---|---|
| `free` | **Gratis** | no Stripe entry | entry tier, **40 pedidos/mes cap** |
| `pro_monthly` | **Pro · Mensual** | **$199 MXN/mes** (Stripe `price_1TQgsp58g89ERoPrzw3U7GQ5`) | uncapped pedidos, full Pro feature set |
| `pro_yearly`  | **Pro · Anual**   | **$1,990 MXN/año** (Stripe `price_1TQgsp58g89ERoPrPaVTz8A3`) | 2 meses gratis vs mensual (−16.7%) |

Display strings live under `t("subscription.plans.*")` in `config/locales/es-MX/domain.yml`. Both Pro prices belong to the same Stripe product `prod_UPVu3WmAhMdJKm` (Kitchef Pro). Trial: 14 días, sin tarjeta (`payment_method_collection: 'if_required'` on the Checkout Session, plus a single-use guard via `customer.metadata.has_trialed`). Save-flow coupon: `ucUpunx9` (50% off × 3 meses, repeating).

### Flow
1. Operator clicks *Mejorar a Pro*.
2. `Subscriptions::CreateCheckoutSession` command generates Stripe Checkout URL.
3. Operator completes checkout in MXN.
4. Stripe webhook `checkout.session.completed` → `Webhooks::StripeHandler` → `Subscriptions::ActivatePro` command updates the `Subscription` record.
5. Operator sees Pro features unlocked instantly (via Turbo Stream refresh of nav).

### Downgrade
- Cancellation sets `cancel_at_period_end: true`.
- At period end, webhook `customer.subscription.deleted` → `Subscriptions::DowngradeToFree`.
- Operator keeps all data but loses Pro features; pedido-count cap re-applies.

### Free tier enforcement
- `Subscriptions::PlanLimitCheck` service runs before every `Orders::PlaceOrder`:
  - If `account.subscription.plan_free?` and `account.orders.where(created_at: current_month).count >= 20`, command fails with `:over_limit`.
  - Public storefront shows "Esta cocina no está aceptando pedidos en este momento" if over limit.
  - Operator sees persistent upsell banner.

---

## 10. Notifications

Uses **Noticed** with two delivery channels:

- `Noticed::DeliveryMethods::Database` — always
- `Noticed::DeliveryMethods::ActionCable` (via Turbo Streams) — for in-app live bell
- `Noticed::DeliveryMethods::Email` (via `noticed-email` if separate, or via Action Mailer directly) — optional, based on user preference

### Event types
- `NewOrderNotification` — public storefront pedido lands in operator's board
- `PaymentReceivedNotification` — operator records a payment
- `OrderReadyToDeliverNotification` — state transitions to `listo`
- `SubscriptionRenewedNotification` / `SubscriptionFailedNotification` — Stripe webhook events

### Email deliveries (production)
- Via **Resend** (`resend` gem)
- Configured in `config/environments/production.rb`:

```ruby
config.action_mailer.delivery_method = :resend
config.action_mailer.resend_settings = { api_key: Rails.application.credentials.resend.api_key }
```

### Email deliveries (development)
- Via **letter_opener_web**, mounted at `/letter_opener`

---

## 11. Background Jobs

### Sidekiq configuration
- **Valkey** as backend — shared connection via `Rails.application.config.redis_config` (single source of truth for Sidekiq, Rails.cache, Action Cable).
- Driver: `hiredis` (set globally via `RedisClient.default_driver` in the Sidekiq initializer).
- `config/sidekiq.yml` with queues: `critical`, `default`, `mailers`, `notifications`, `imports`, `low`.
- Web UI mounted at `/admin/sidekiq` inside the admin namespace (AdminConstraint-gated).

### Scheduled jobs (sidekiq-cron)
- `DailyOperatorDigestJob` — 7am MX time, emails summary to operators with `digest_enabled: true`
- `BirthdayReminderJob` — 6am MX time, notifies operators of client birthdays this week
- `IngredientPriceStalenessJob` — weekly, flags ingredients not updated in 30+ days
- `SubscriptionReconciliationJob` — hourly, reconciles Stripe webhook drift
- `MenuEngineeringRecalcJob` — nightly, precomputes matrices for faster panel loads
- `SitemapGeneratorJob` — weekly, via `sitemap_generator`
- `PickupReminderScanJob` — every 15 minutes, finds pickup pedidos in `ready` longer than each account's `pickup_reminder_hours` with `pickup_reminder_sent_at IS NULL`, enqueues a `PickupReminderJob` per pedido (operator notification + Noticed event; `pickup_reminder_sent_at` stamp prevents repeats). The scan is cheap — bounded by ready-but-not-delivered pickup pedidos, indexed on `(state, delivery_type, ready_at)`.

---

## 12. File Storage

### ActiveStorage setup
- Service `:local` in dev (disk)
- Service `:amazon` in prod (S3, configured via `aws-sdk-s3`)
- All uploads validated via `active_storage_validations`:
  - Max 5 MB per image
  - Content types: `image/jpeg`, `image/png`, `image/webp`, `image/heic`
  - Dimensions: min 400x400, max 4000x4000

### Image processing
- `image_processing` + `ruby-vips` (both in Gemfile)
- Variants defined on model:
  - `thumb` — 120×120, smart_crop
  - `card` — 400×400, smart_crop
  - `hero` — 1200×800, resize_to_limit

### Attachments
- `Account` — `logo`, `cover_photo`
- `Recipe` — `photos` (has_many_attached, max 5)
- `User` — `avatar`

---

## 13. Money & Currency

### Configuration

```ruby
# config/initializers/money.rb
Money.locale_backend = :i18n
Money.rounding_mode = BigDecimal::ROUND_HALF_UP
Money.default_currency = "MXN"

MoneyRails.configure do |config|
  config.default_currency = :mxn
  config.rounding_mode = BigDecimal::ROUND_HALF_UP
  config.locale_backend = :i18n
  config.amount_column = { prefix: "", postfix: "_cents" }
  config.no_cents_if_whole = false
  config.symbol = "$"
end
```

### Model conventions
- Every monetary column is `_cents` (BIGINT) + `_currency` (defaults to MXN, rarely stored)
- Use `monetize :total_cents` in model
- View formatting: `humanized_money_with_symbol(order.total)` → `$1,250.00`
- **Never display USD.** Even if the operator were to travel, MXN is hard-coded in UI.

---

## 14. Phone Numbers

### Configuration

```ruby
# config/initializers/phonelib.rb
Phonelib.default_country = "MX"
Phonelib.override_phone_regexp = nil
Phonelib.strict_validation = true
```

### Model conventions
- Store `phone` (raw input) + `phone_normalized` (E.164 format)
- `phony_normalize :phone, as: :phone_normalized, default_country_code: "MX"`
- WhatsApp deep link helper:

```ruby
# app/helpers/whatsapp_helper.rb
module WhatsappHelper
  def whatsapp_link(phone, message = nil)
    normalized = Phonelib.parse(phone, "MX").e164.sub(/^\+/, "")
    base = "https://wa.me/#{normalized}"
    message ? "#{base}?text=#{CGI.escape(message)}" : base
  end
end
```

---

## 15. Localization

### Primary locale
- `es-MX` is the default, hardcoded in `config/application.rb`:
```ruby
config.i18n.default_locale = :"es-MX"
config.i18n.available_locales = [:"es-MX"]
config.time_zone = "America/Mexico_City"
```
- `rails-i18n` provides Rails baseline translations
- Custom translations under `config/locales/es-MX.yml`
- All model attributes, validation messages, and UI strings translated

### Pluralization
- Spanish pluralization via Rails-i18n
- Money pluralization: *un peso / dos pesos*

### Date/time formatting
- Use `local_time` helper for displaying times (server renders UTC ISO-8601, client formats to user TZ)
- Default formats in `config/locales/es-MX.yml`:
  - `date.formats.default`: `%d de %B de %Y` → "12 de mayo de 2026"
  - `date.formats.short`: `%d/%m/%Y`
  - `time.formats.default`: `%d/%m/%Y %H:%M`

### Groupdate
- For report grouping: `Order.group_by_week(:delivery_date).count` — uses `America/Mexico_City`

---

## 16. Frontend Stack

### Importmap configuration
```ruby
# config/importmap.rb
pin "application"
pin "@hotwired/turbo-rails",       to: "turbo.min.js"
pin "@hotwired/stimulus",          to: "stimulus.min.js"
pin "@hotwired/stimulus-loading",  to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
```

**Flowbite dropped.** The original plan paired Flowbite with a custom palette, but `DESIGN.md`'s token system (deep green accent, bone background, Instrument Serif / Inter / JetBrains Mono) is bespoke enough that Flowbite's component styling would fight every utility. Bespoke `app/components/ui/*` primitives map directly to `DESIGN.md` specs with zero override cost. If we ever need a specific Flowbite JS behavior (e.g., complex datepicker), we pull in the standalone JS widget and re-style; we don't bring in the full library.

### Tailwind CSS v4 (CSS-first)

Configured via `tailwindcss-rails` 4.x. The config and tokens live in `app/assets/tailwind/application.css` using Tailwind v4's `@theme` directive — no `tailwind.config.js`. Dark mode via the `.dark` class (pre-paint boot in `app/javascript/theme_bootstrap.js` to prevent FOUC).

```css
/* app/assets/tailwind/application.css */
@import "tailwindcss";

@source "../../components/**/*.{rb,erb,html,html.erb}";
@source "../../views/**/*.{erb,html,html.erb}";
@source "../../helpers/**/*.rb";
@source "../../javascript/**/*.js";

@custom-variant dark (&:where(.dark, .dark *));

@theme {
  --font-serif: "Instrument Serif", Georgia, serif;
  --font-sans:  "Inter", -apple-system, system-ui, sans-serif;
  --font-mono:  "JetBrains Mono", ui-monospace, monospace;

  --color-ink:         #0E1714;
  --color-ink-2:       #2F3A35;
  --color-muted:       #6B7670;

  --color-bg:          #F8F6F1;   /* bone, NEVER pure white */
  --color-bg-2:        #EFEBE3;
  --color-surface:     #FFFFFF;

  --color-accent:      #0A5A3C;   /* deep green */
  --color-accent-2:    #074830;
  --color-accent-soft: #E3EDE6;

  --radius-button: 9px;
  --radius-card:   14px;
  --radius-panel:  20px;
  --radius-pill:   99px;
  /* …shadows, status tokens, etc. */
}

.dark { --color-ink: #F2EFE8; /* …dark overrides… */ }
```

The full token set (status, radii, shadows) and design rationale live in `DESIGN.md` — that document is the source of truth for anything visual.

### Stimulus controllers

Live in `app/javascript/controllers/`. Already shipped: `theme_controller.js` (auto → light → dark cycle, labels passed from ERB via `data-theme-*-label-value`). Others land with their feature PRs:

- `currency_input_controller.js` — MXN input formatting
- `phone_input_controller.js` — MX phone formatting as user types
- `sortable_controller.js` — drag-and-drop via `positioning` gem endpoint
- `auto_submit_controller.js` — live-search inputs

**No inline JS in views.** Pre-paint boot code goes in `app/javascript/*.js` and is loaded via `javascript_include_tag` in `<head>`. Interactive behavior goes through Stimulus. Labels/copy are passed from ERB via `data-*-value` attributes so translations stay on the server.

### Turbo
- Frame-based navigation for operator sections (avoids full reloads).
- Stream broadcasts from models for real-time kanban updates.
- Morphing enabled (`data-turbo-action="morph"`) for kanban column moves.
- **Controllers that forms redirect to MUST return HTML.** Turbo silently bails on `text/plain` after a form submit — the URL bar doesn't change and the flow looks broken. Use `render_stub(title:, meta:)` (defined on `ApplicationController`) for Phase 6 placeholders — it renders the shared `app/views/shared/stub.html.erb` template with a proper `text/html` content type.

### View components directory layout

```
app/components/
├── ui/                         # Bespoke primitives (DESIGN.md tokens)
│   ├── button_component.rb     # :default, :primary, :ghost variants
│   ├── badge_component.rb      # status pills (listo/nuevo/en_produccion/atrasado)
│   ├── card_component.rb       # default, compact, showcase variants
│   ├── dropdown_component.rb
│   ├── modal_component.rb      # native <dialog>-based
│   └── form/
│       ├── field_component.rb
│       ├── money_input_component.rb
│       └── phone_input_component.rb
├── layouts/
│   ├── panel_nav_component.rb
│   └── storefront_nav_component.rb
├── orders/
│   ├── card_component.rb
│   ├── kanban_column_component.rb
│   └── state_pill_component.rb
├── recipes/
│   ├── card_component.rb
│   └── cost_breakdown_component.rb
└── storefronts/
    ├── hero_component.rb
    └── menu_item_component.rb
```

---

## 17. Email

### Development
- `letter_opener_web` mounted at `/letter_opener` (renamed from the original `/cartas` to use the gem's conventional mount path — easier to spot in routes, doesn't require explaining to new contributors).
- `letter_opener` ensures emails open in the browser on send.

### Production
- **Resend** via `resend` gem
- API key in Rails credentials
- From addresses:
  - `hola@kitchef.mx` — product emails
  - `pedidos@kitchef.mx` — order-related
  - `cuenta@kitchef.mx` — billing

### Transactional emails (v1)
- `UserMailer#welcome` — after signup
- `UserMailer#password_reset` — Rails auth
- `OrdersMailer#client_confirmation` — sent to customer after public order
- `OrdersMailer#operator_new_order` — optional, based on operator preference
- `BillingMailer#subscription_activated` / `#payment_failed`

---

## 18. SEO & Marketing

### Sitemap
- `sitemap_generator` with custom rules:
  - Marketing pages (home, pricing, how-it-works, FAQ)
  - Public storefronts where `account.discoverable?` is true
  - Individual recipes on discoverable storefronts
- Regenerated weekly via `SitemapGeneratorJob`
- Uploaded to S3 and served at `/sitemap.xml.gz`

### Meta tags
- Default via `ApplicationHelper#page_meta(title:, description:)`
- Storefront-specific via Account profile
- Open Graph + Twitter Card for every public page
- Structured data (`LocalBusiness`, `Restaurant`, `MenuItem`) on storefronts — essential for Google discovery

---

## 19. Gems & Their Roles

Organized by category, matching the reference Gemfile structure. This is the canonical list for `Gemfile`:

### Core framework
| Gem | Role |
|---|---|
| `rails` (~> 8.1) | Framework |
| `rails-i18n` | Base translations |
| `puma` | App server |
| `thruster` | HTTP accelerator |
| `propshaft` | Asset pipeline |
| `bootsnap` | Boot performance |
| `importmap-rails` | JS without Node |

### Database & caching
| Gem | Role |
|---|---|
| `pg` | PostgreSQL driver |
| `redis`, `hiredis-client` | Valkey client |
| `connection_pool` | Connection pooling |

### Auth & security
| Gem | Role |
|---|---|
| `bcrypt` | Password hashing |
| `omniauth`, `omniauth-google-oauth2`, `omniauth-rails_csrf_protection` | OAuth (Google in v1.1) |
| `rack-attack` | Rate limiting |
| `rack-cors` | CORS policy |

### UI & frontend
| Gem | Role |
|---|---|
| `tailwindcss-rails` | Tailwind |
| `turbo-rails`, `stimulus-rails` | Hotwire |
| `view_component` | Components |
| `lucide-rails` | Icon helper |
| `local_time` | Client-side time formatting |
| `simple_calendar` | Calendar views |

### Domain-specific
| Gem | Role |
|---|---|
| `money`, `money-rails` | Money handling, MXN default |
| `phonelib`, `phony_rails` | Phone normalization, MX default |
| `name_of_person` | First/last name handling |
| `interval_set` | Delivery slot capacity |
| `positioning` | Drag-reorder lists |
| `friendly_id` | Slugs |
| `prefixed_ids` | `ord_xyz` human IDs |
| `aasm` | Order state machine |
| `discard` | Soft deletes |
| `paper_trail` | Audit trail |
| `store_model` | JSONB structured data |
| `ransack` | Search/filter |

### Background & async
| Gem | Role |
|---|---|
| `sidekiq`, `sidekiq-cron` | Background jobs |
| `noticed` | Notifications |

### Views & formatting
| Gem | Role |
|---|---|
| `decent_exposure` | Controller cleanup |
| `draper` | Decorators (used sparingly; prefer VC) |
| `pagy` | Pagination |
| `chartkick` | Charts |
| `groupdate` | Date grouping for reports |
| `caxlsx` | Excel export |
| `rqrcode` | QR codes |
| `oj`, `oj_serializers` | JSON serialization |

### Storage & media
| Gem | Role |
|---|---|
| `active_storage_validations` | Upload validations |
| `image_processing`, `ruby-vips` | Variants |
| `aws-sdk-s3` | Production storage |

### Integrations
| Gem | Role |
|---|---|
| `stripe` | Subscriptions |
| `resend` | Transactional email |
| `twilio-ruby` | SMS reminders (v1.1) |
| `geocoder` | Colonia → coords for route planning |

### Configuration & patterns
| Gem | Role |
|---|---|
| `rails-settings-cached` | Global settings |
| `dry-initializer`, `dry-initializer-rails`, `dry-types` | Service object ergonomics |
| `light-service` | Multi-step workflows (used sparingly) |
| `validate_url` | URL validators |

### Deployment & observability
| Gem | Role |
|---|---|
| `kamal` | Deploy |
| `sentry-rails`, `sentry-ruby`, `sentry-sidekiq` | Error tracking |
| `posthog-rails`, `posthog-ruby` | Product analytics |
| `sitemap_generator` | Sitemaps |

### Development only
| Gem | Role |
|---|---|
| `annotaterb` | Schema annotations |
| `dotenv-rails` | Env management |
| `letter_opener_web` | Dev email preview |
| `hotwire-spark` | Dev live-reload |
| `rack-mini-profiler` | Perf profiling |
| `web-console` | In-browser console |
| `solargraph-rails` | LSP |
| `faker`, `factory_bot_rails` | Seeds / fixtures |
| `rubocop-rails-omakase`, `rubocop-rails`, `rubocop-performance`, `rubocop-factory_bot`, `rubocop-faker` | Linting |
| `brakeman`, `bundler-audit` | Security scanning |

---

## 20. Directory Organization

```
kitchef/
├── app/
│   ├── commands/              # Write-side business actions
│   │   ├── application_command.rb
│   │   ├── orders/
│   │   │   ├── place_order.rb
│   │   │   ├── confirm_order.rb
│   │   │   ├── add_item.rb
│   │   │   └── ...
│   │   ├── recipes/
│   │   │   ├── decompose.rb
│   │   │   ├── add_component.rb
│   │   │   ├── convert_to_internal.rb
│   │   │   ├── promote_to_saleable.rb
│   │   │   └── update_cost_snapshot.rb
│   │   ├── ingredients/
│   │   │   └── update_price.rb
│   │   ├── subscriptions/
│   │   └── onboarding/
│   │       └── complete_first_decomposition.rb
│   ├── components/            # ViewComponent
│   │   ├── application_component.rb
│   │   ├── ui/
│   │   ├── layouts/
│   │   ├── orders/
│   │   ├── recipes/
│   │   │   ├── form_component.rb
│   │   │   ├── card_component.rb
│   │   │   ├── cost_breakdown_component.rb
│   │   │   ├── component_picker_component.rb
│   │   │   ├── decomposition_tree_component.rb
│   │   │   └── simple_form_component.rb   # simple-mode only
│   │   └── storefronts/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── marketing_controller.rb
│   │   ├── panel/
│   │   │   ├── base_controller.rb
│   │   │   ├── dashboards_controller.rb
│   │   │   ├── orders_controller.rb
│   │   │   ├── recipes_controller.rb
│   │   │   ├── ingredients_controller.rb
│   │   │   ├── onboarding/
│   │   │   │   └── decomposition_controller.rb
│   │   │   └── ...
│   │   ├── storefronts/
│   │   │   ├── base_controller.rb
│   │   │   ├── orders_controller.rb
│   │   │   └── menus_controller.rb
│   │   └── webhooks/
│   │       └── stripe_controller.rb
│   ├── helpers/
│   ├── javascript/
│   │   ├── application.js
│   │   └── controllers/
│   │       ├── recipe_form_controller.js        # adapts to composable mode
│   │       ├── component_picker_controller.js
│   │       ├── cost_preview_controller.js        # live preview of cost as user types
│   │       └── ...
│   ├── jobs/
│   │   ├── recipes/
│   │   │   └── update_cost_snapshot_job.rb
│   │   └── ...
│   ├── mailers/
│   ├── models/
│   │   ├── application_record.rb
│   │   ├── account.rb
│   │   ├── accounts/
│   │   │   └── settings.rb              # StoreModel
│   │   ├── concerns/
│   │   │   ├── has_prefixed_id.rb
│   │   │   ├── has_soft_delete.rb
│   │   │   └── account_scoped.rb
│   │   ├── ingredient.rb
│   │   ├── recipe.rb
│   │   ├── recipe_component.rb          # polymorphic join
│   │   └── ...
│   ├── notifications/         # Noticed events
│   ├── policies/              # (reserved for v2 when multi-user)
│   ├── queries/               # Read-side queries
│   │   ├── application_query.rb
│   │   ├── reports/
│   │   │   ├── menu_engineering_matrix.rb
│   │   │   └── ingredient_impact_analysis.rb
│   │   ├── production/
│   │   │   └── weekly_shopping_list.rb
│   │   └── finance/
│   │       └── monthly_margins.rb
│   ├── services/              # Coordinators
│   │   ├── application_service.rb
│   │   ├── billing/
│   │   ├── recipes/
│   │   │   ├── cost_calculator.rb
│   │   │   ├── cycle_detector.rb
│   │   │   ├── dependency_graph.rb
│   │   │   └── unit_converter.rb
│   │   ├── storefronts/
│   │   └── whatsapp/
│   └── views/
├── bin/
│   └── check_reserved_slugs   # CI guard for root-level slugs
├── config/
├── db/
├── docker/
│   ├── postgres/
│   │   ├── Dockerfile
│   │   ├── Aptfile
│   │   ├── .psqlrc
│   │   ├── create_extensions.sql
│   │   ├── init.sh
│   │   └── postgresql.conf
│   └── valkey/
│       ├── Dockerfile
│       └── valkey.conf
├── lib/
├── public/
├── Dockerfile
├── compose.yml
├── Gemfile
└── ...
```

---

## 21. Docker & Local Development

### Reference
Modeled after Agendario's structure (https://github.com/samacs/agendario.mx) with a few intentional deviations noted below.

### Production Dockerfile
Based on Agendario's. Key elements:
- Ruby 4.0.2-slim base (tracks `.ruby-version`)
- jemalloc preloaded
- Two-stage build (base + build + final)
- Non-root `rails` user (UID/GID 1000)
- `RAILS_ENV=production`, `BUNDLE_DEPLOYMENT=1`
- Thruster entrypoint on port 80

### compose.yml (actual structure)
```yaml
---
name: kitchef

x-postgres-env: &postgres-env
  POSTGRES_USER: ${POSTGRES_USER:-kitchef}
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-kitchef}
  POSTGRES_DB: ${POSTGRES_DB:-kitchef_development}

services:
  postgres:
    build:
      context: .
      dockerfile: ./docker/postgres/Dockerfile
      args:
        POSTGRES_MAJOR: ${POSTGRES_MAJOR:-18}
    image: ${DOCKER_REGISTRY:-kitchef.mx}/${DOCKER_REPOSITORY:-kitchef}-postgres:${TAG:-latest}
    hostname: kitchef-postgres
    container_name: kitchef-postgres
    restart: unless-stopped
    environment:
      <<: *postgres-env
      PGDATA: /var/lib/postgresql/data/pgdata
    ports: [ "${POSTGRES_PORT:-5432}:5432" ]
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./docker/postgres/init.sh:/docker-entrypoint-initdb.d/10-init.sh:ro
      - ./docker/postgres/create_extensions.sql:/docker-entrypoint-initdb.d/20-create_extensions.sql:ro
      - ./docker/postgres/.psqlrc:/root/.psqlrc:ro
    healthcheck:
      test: [ "CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}" ]
      interval: 10s
      timeout: 5s
      retries: 5

  valkey:
    build:
      context: .
      dockerfile: ./docker/valkey/Dockerfile
      args:
        VALKEY_MAJOR: ${VALKEY_MAJOR:-9}
    image: ${DOCKER_REGISTRY:-kitchef.mx}/${DOCKER_REPOSITORY:-kitchef}-valkey:${TAG:-latest}
    hostname: kitchef-valkey
    container_name: kitchef-valkey
    restart: unless-stopped
    ports: [ "${VALKEY_PORT:-6379}:6379" ]
    volumes: [ valkey-data:/data ]
    healthcheck:
      test: [ "CMD", "valkey-cli", "ping" ]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres-data:
  valkey-data:
```

**Deviations from a literal Agendario mirror, each documented in source:**
1. **No `DISTRO_NAME` arg** at the compose layer. The original spec had `DISTRO_NAME` as an arg on *both* services with different defaults (`trixie` for postgres, `alpine` for valkey) — a single env var can't legitimately hold two values, so if you set it in `.env` one service breaks. Each `Dockerfile` keeps its own `ARG DISTRO_NAME=…` default; we don't surface it to compose.
2. **Health checks on both services** (`pg_isready`, `valkey-cli ping`). Enables `depends_on: { condition: service_healthy }` when we add a web container later.
3. **Init scripts are bind-mounted, not COPY'd into the image.** `docker/postgres/init.sh` and `create_extensions.sql` are mounted read-only into `/docker-entrypoint-initdb.d/` with numeric prefixes that force init order (10 then 20). Changes don't require a rebuild (they take effect on the next fresh volume init; existing volumes keep their schema).
4. **`.psqlrc` is bind-mounted** to `/root/.psqlrc` so `docker exec kitchef-postgres psql` sessions get `\timing`, verbose error reports, and the `[NULL]` null indicator.

### Postgres extensions
```sql
-- docker/postgres/create_extensions.sql (runs on fresh init)
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

### Dev SSL — lvh.me + mkcert

The dev server runs HTTPS on `https://lvh.me:3000` — not `http://localhost:3000`. Reasons:
- `localhost` is refused by several third-party services as an OAuth redirect URI or webhook origin (Stripe Connect, some WhatsApp providers, Google OAuth). `lvh.me` resolves to 127.0.0.1 and behaves like a real domain.
- HTTPS from day one avoids HSTS gotchas, prevents mixed-content when we pull CDN assets, and matches production identically so a dev never hits a bug that only manifests under TLS.

Certs live in `./ssl/lvh.me.pem` + `./ssl/lvh.me.key`, generated per-machine via `mkcert` (one-time: `brew install mkcert && mkcert -install && mkcert -key-file ssl/lvh.me.key -cert-file ssl/lvh.me.pem lvh.me "*.lvh.me" localhost 127.0.0.1`). The `ssl/` directory is gitignored; each dev regenerates their own.

`bin/dev` sets `SSL_CERT_FILE` / `SSL_KEY_FILE` env vars and hands them to Puma via `Procfile.dev`:

```
web: bin/rails server -b "ssl://0.0.0.0:${PORT:-3000}?key=${SSL_KEY_FILE}&cert=${SSL_CERT_FILE}"
css: bin/rails tailwindcss:watch
worker: bin/sidekiq -C config/sidekiq.yml
```

`config/environments/development.rb` widens `config.hosts` to include `lvh.me` and its subdomain regex, and sets `default_url_options = { host: "lvh.me", port: 3000, protocol: "https" }` on `config.action_controller` + `config.action_mailer` + `Rails.application.routes` — otherwise `root_url` can drop `:3000`/`https://` when generated outside a request (mailers, jobs), and a sign-in redirect lands at a dead `http://lvh.me/`.

### `.env` (via dotenv-rails)
```
# Database
POSTGRES_USER=kitchef
POSTGRES_PASSWORD=kitchef
POSTGRES_DB=kitchef_development
POSTGRES_PORT=5432
POSTGRES_MAJOR=18
DATABASE_URL=postgres://kitchef:kitchef@localhost:5432/kitchef_development

# Valkey (Redis-compatible)
VALKEY_PORT=6379
VALKEY_MAJOR=9
VALKEY_URL=redis://localhost:6379/0

# Rails
RAILS_MASTER_KEY=
PREFIXED_IDS_SALT=kitchef-dev-salt-replace-in-prod

# OAuth / payments / email / storage / observability
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=
STRIPE_PUBLISHABLE_KEY=pk_test_
STRIPE_SECRET_KEY=sk_test_
STRIPE_WEBHOOK_SECRET=whsec_
RESEND_API_KEY=re_
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_WHATSAPP_FROM=
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=us-east-2
S3_BUCKET=kitchef-dev-uploads
SENTRY_DSN=
POSTHOG_API_KEY=
```

### Shared Valkey config

A single `Rails.application.config.redis_config` hash in `config/application.rb` is the source of truth for every Valkey connection (Sidekiq, Rails.cache, Action Cable, ad-hoc consumers):

```ruby
# config/application.rb
config.redis_config = {
  url:    ENV.fetch("VALKEY_URL", "redis://localhost:6379/0"),
  driver: :hiredis
}
```

`config/initializers/sidekiq.rb` reads this hash for both server and client, sets `RedisClient.default_driver`, and loads `config/schedule.yml` (sidekiq-cron) when present. Cache stores in `development.rb` and `production.rb` `.merge` pool/timeout options on top.

---

## 22. Deployment (Kamal)

v1 deployment via Kamal to a single VPS (Hetzner or DigitalOcean, 2 vCPU + 4 GB RAM is enough for hundreds of tenants).

- One web container (Rails + Thruster)
- One worker container (Sidekiq)
- Managed Postgres (optional — local in a container is fine until scale demands otherwise)
- Managed Valkey (same note)
- Cloudflare in front for CDN + DDoS protection
- Let's Encrypt via Kamal's built-in proxy

---

## 23. Code Style & Quality

### RuboCop
- Base: `rubocop-rails-omakase`
- Plus: `rubocop-rails`, `rubocop-performance`, `rubocop-factory_bot`, `rubocop-faker`
- Enforced in CI
- `.rubocop.yml` exemptions: none initially; add as pragmatism demands

### Schema annotations
- `annotaterb` runs after every migration in dev
- Keeps models self-documenting

### Security scanning
- `brakeman` in CI
- `bundler-audit` in CI

### Reserved slug guard (custom CI rule)

Because account slugs live at the root level, every top-level route must have a matching entry in `Account::RESERVED_SLUGS`. A lightweight custom CI script enforces this. The script lives at `bin/check_reserved_slugs` and runs after tests:

```ruby
#!/usr/bin/env ruby
# bin/check_reserved_slugs
# Ensures every top-level route in config/routes.rb has a corresponding
# entry in Account::RESERVED_SLUGS.

require_relative "../config/environment"

# Parse all top-level route paths from the Rails routes table
top_level_paths = Rails.application.routes.routes.map do |route|
  path = route.path.spec.to_s
  next unless path.match?(%r{\A/[^/:*]+(?:/|\z|\()})  # /foo, /foo/, /foo(.:format)
  path.sub(%r{\A/}, "").split(/[/.(]/).first
end.compact.uniq

# Paths that legitimately don't need reserving (e.g., the storefront slug route itself)
EXEMPT = %w[].freeze

unreserved = top_level_paths - Account::RESERVED_SLUGS - EXEMPT

if unreserved.any?
  warn "❌ These top-level routes are not in Account::RESERVED_SLUGS:"
  unreserved.each { |p| warn "   - #{p}" }
  warn "\nAdd them to RESERVED_SLUGS in app/models/account.rb"
  exit 1
end

puts "✅ All top-level routes are reserved."
```

CI step runs: `bundle exec bin/check_reserved_slugs`. Fails the build if any route is missing from the reserved list.

### No tests in v1
- Per owner decision, formal testing is deferred
- `factory_bot_rails` + `faker` kept for seeds
- `db:seed` uses factories to create realistic demo data for each developer

---

## 24. Observability

### Error tracking — Sentry
- `sentry-rails` + `sentry-ruby` + `sentry-sidekiq`
- DSN via env var
- Sample rate: 1.0 in v1 (low volume), reduce later

### Product analytics — PostHog
- `posthog-rails` + `posthog-ruby`
- Self-hosted PostHog acceptable (matches Saul's preference for self-hosted tooling)
- Events tracked:
  - `signup_completed`
  - `first_recipe_added`
  - `first_decomposition_completed` (the moment `use_composable_recipes` flips — the quiet-superpower conversion)
  - `first_order_received`
  - `subscription_upgraded`
  - `storefront_viewed` (on public pages)
  - `onboarding_advanced_mode_chosen` (operator selected advanced mode during signup)

### Profiling
- `rack-mini-profiler` in dev
- `stackprof` available for targeted production profiling

---

## 25. What We're Explicitly Not Building in v1 (Technical Deferrals)

- **Pundit / authorization policies** — deferred until multi-user fonda tier
- **RSpec / Capybara test suite** — deferred per owner decision
- **GraphQL / JSON:API** — Rails renders HTML; small number of JSON endpoints use `oj_serializers` inline
- **Service Worker / PWA manifest** — responsive web is enough for v1; PWA in v1.2
- **Background image processing with pre-warmed variants** — lazy on first request, cache-backed
- **Sharding / read replicas** — single database until meaningful scale
- **Event sourcing / CQRS** — paper_trail gives enough auditability
- **Kubernetes / microservices** — Kamal single-VPS is correct until it isn't

---

**End of TRD.**
