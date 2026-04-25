# == Schema Information
#
# Table name: accounts
#
#  id               :bigint           not null, primary key
#  branding         :jsonb            not null
#  default_currency :string           default("MXN"), not null
#  discarded_at     :datetime
#  iva_enabled      :boolean          default(FALSE), not null
#  iva_rate_percent :decimal(5, 2)    default(16.0), not null
#  name             :string           not null
#  public_profile   :jsonb            not null
#  settings         :jsonb            not null
#  slug             :string           not null
#  time_zone        :string           default("America/Mexico_City"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  owner_id         :bigint           not null
#
# Indexes
#
#  index_accounts_on_discarded_at  (discarded_at)
#  index_accounts_on_owner_id      (owner_id)
#  index_accounts_on_settings      (settings) USING gin
#  index_accounts_on_slug          (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (owner_id => users.id)
#
class Account < ApplicationRecord
  extend FriendlyId
  include HasPrefixedId.new(prefix: "acc")
  include HasSoftDelete

  friendly_id :name, use: :slugged

  # Root-level slugs live at `kitchef.mx/:slug`. Any name that would collide
  # with an app route has to be blocked at the model layer AND at routing
  # layer (see config/routes.rb storefront constraint) AND in CI (see
  # bin/check_reserved_slugs). This list is expected to grow — keep it
  # alphabetized per block for easy diffs.
  #
  # Grouping mirrors the intent:
  #   1. Kitchef app routes (Spanish — currently shipped).
  #   2. English equivalents of every Spanish route (so an operator can't
  #      pre-empt a future localization surface).
  #   3. Cooking-domain terms — the whole reason Kitchef exists is this
  #      vocabulary, and operators WILL try to register the obvious ones.
  #   4. Common SaaS / auth / billing paths we'll almost certainly add.
  #   5. Tech and protocol paths (robots, sitemap, webhooks, oauth, …).
  #   6. Brand names (ours and look-alikes).
  RESERVED_SLUGS = %w[
    acerca admin ajustes api app asistencia asistente assets ayuda
    blog buscar
    categoria categorias como-funciona compra compras contacto cocina costos costos-fijos
    directorio
    empaque empleos entrar equipo explorar
    facturacion favicon fijos fotos
    gastos
    health
    kitchef
    legal
    nosotros nuestra-historia notificaciones
    pagos panel pedidos plataformas precios prensa privacidad proveedor proveedores preguntas
    rails recetario recetas recuperar recursos registro renta robots
    salir sesion sitemap soporte suministros
    terminos tickets
    up usuarios utilidades
    webhooks

    about account accounts admin-panel api-docs apis auth
    billing
    careers cart categories category changelog checkout clients company contact cookies
    dashboard demo docs docs-api documentation
    enterprise explore expenses expense
    faq features feedback fixed fixed-cost-categories fixed-costs forgot-password
    help home how-it-works
    integrations
    jobs join
    letter_opener login logout
    menus
    new news notifications
    onboarding
    packaging password passwords platform platforms pricing privacy production products profile purchase purchases
    r register rent reports reset-password root
    schedule search settings sign-in signin sign-out signout sign-up signup supplier suppliers
    stats status subscribe subscription support
    team terms tour
    users utilities
    vendor vendors
    welcome

    baker baking bakery
    chef chefs cocinera cocineras cocinero cocineros cook cooking cuisine
    delivery deliveries
    food foods foodie
    ingredient ingredients
    kitchen kitchens
    meal meals menu
    order orders
    platillo platillos
    receta recipe recipes restaurant restaurante
    taller tamales tienda

    analytics assets-cdn atom
    cable callback callbacks css
    embed
    feed ftp
    graphql
    img images
    js json
    mail mailer metrics
    oauth oauth2 oembed opensearch
    ping public
    recede_historical_location refresh_historical_location resume_historical_location
    rss
    sidekiq
    ssh static superuser
    www
    xml

    kitchef-mx kitchef-io agendario
  ].freeze

  belongs_to :owner, class_name: "User", inverse_of: :owned_account

  # Declaration order matters: dependent-destroy cascades run in the order
  # associations are declared. Orders must run before recipes/ingredients
  # (OrderItems reference Recipes). Clients after orders (orders nullify
  # client_id). Users cascades so destroying the owner tears down any
  # other members with it — the owner's `before_destroy :detach_from_account`
  # pre-nulls the circular FK so this doesn't loop back onto itself.
  has_many :users,                  dependent: :destroy
  has_many :orders,                 dependent: :destroy
  has_many :purchases,              dependent: :destroy   # PurchaseItem FK → ingredients (cascade)
  has_many :clients,                dependent: :destroy
  has_many :suppliers,              dependent: :destroy   # SupplierIngredient FK → ingredients (cascade)
  has_many :recipes,                dependent: :destroy
  has_many :ingredients,            dependent: :destroy
  has_many :fixed_costs,            dependent: :destroy   # before categories — FKs into fixed_cost_categories
  has_many :fixed_cost_categories,  dependent: :destroy
  has_many :categories,             dependent: :destroy   # last — ingredients + recipes FK to it
  has_one  :schedule,               dependent: :destroy, inverse_of: :account
  has_one  :subscription,           dependent: :destroy

  # Every account boots with a blank Schedule so storefront code can count
  # on `account.schedule` being non-nil. Operators fill it in from
  # `/schedule`; until then, the picker surfaces a "no horarios yet" state
  # rather than blowing up.
  after_create :ensure_schedule
  after_create :bootstrap_default_categories
  after_create :bootstrap_default_fixed_cost_categories

  # Idempotent fetch-or-create, for cases where the `after_create` callback
  # didn't run (pre-Phase-6 accounts backfilled via the data migration, or
  # direct SQL inserts in tests).
  def schedule!
    schedule || create_schedule!(order_mode: :advance, lead_time_minutes: 0)
  rescue ActiveRecord::RecordNotUnique
    reload_schedule
  end

  # Variants match the three shapes the logo is rendered at across the
  # app: operator-app header avatar, storefront header mark, and
  # storefront hero badge. Declared on the attachment so `variant(:card)`
  # works everywhere without per-call `variant(resize_to_limit: …)`.
  has_one_attached :logo do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 120, 120 ]
    attachable.variant :card,  resize_to_fill: [ 360, 360 ]
    attachable.variant :hero,  resize_to_limit: [ 800, 800 ]
  end

  # Cover variants are landscape: `card` is the config-page preview
  # thumbnail; `hero` is the storefront's full-bleed cover.
  has_one_attached :cover_photo do |attachable|
    attachable.variant :card, resize_to_fill: [ 640, 360 ]
    attachable.variant :hero, resize_to_fill: [ 1600, 800 ]
  end

  attribute :settings,       Accounts::Settings.to_type
  attribute :public_profile, Accounts::PublicProfile.to_type
  attribute :branding,       Accounts::Branding.to_type

  validates :name, presence: true, length: { maximum: 80 }
  validates :slug,
    presence: true,
    uniqueness: true,
    length: { minimum: 3, maximum: 50 },
    format: {
      with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
      message: :slug_format
    },
    exclusion: { in: RESERVED_SLUGS, message: :slug_reserved }

  validates :default_currency, presence: true
  validates :time_zone,        presence: true

  scope :with_composable_recipes, -> {
    where("accounts.settings @> ?", { use_composable_recipes: true }.to_json)
  }

  # Convenience: true when the operator has opted into advanced mode.
  def composable_recipes?
    settings.use_composable_recipes
  end

  # Canonical slug computation shared by the JSON endpoint, the live
  # preview in the onboarding form, and FriendlyID's default
  # normalization on save. Keeping this in one place means the
  # preview URL the operator sees in the form matches the URL her
  # storefront actually ships with.
  def self.slugify(value)
    value.to_s.parameterize
  end

  # FriendlyID: don't regenerate the slug after the first save. A storefront
  # URL that changes silently breaks every receipt and screenshot ever
  # shared.
  def should_generate_new_friendly_id?
    slug.blank?
  end

  # Per-account default Category rows — the starting buckets Phase 9
  # hands every new operator (matches the Spanish names the data
  # migration backfilled for existing accounts). Idempotent so re-runs
  # (console exploration, test helpers) don't double-seed.
  DEFAULT_INGREDIENT_CATEGORIES = [
    "Abarrotes", "Carnes", "Lácteos", "Frutas y verduras", "Especias", "Otros"
  ].freeze

  DEFAULT_RECIPE_CATEGORIES = [
    "Platos fuertes", "Entradas", "Postres", "Bebidas", "Bases y preparaciones", "Otros"
  ].freeze

  # Phase 10 — five starter buckets for fixed-cost tracking. Matches the
  # kinds on FixedCostCategory (rent / utilities / packaging / platform /
  # other). Operators add more via the inline combobox on /costos-fijos.
  DEFAULT_FIXED_COST_CATEGORIES = [
    [ "Renta",            :rent ],
    [ "Gas y servicios",  :utilities ],
    [ "Empaque",          :packaging ],
    [ "Plataformas",      :platform ],
    [ "Otros",            :other ]
  ].freeze

  private

  def ensure_schedule
    create_schedule!(order_mode: :advance, lead_time_minutes: 0) if schedule.nil?
  rescue ActiveRecord::RecordNotUnique
    reload_schedule
  end

  def bootstrap_default_categories
    DEFAULT_INGREDIENT_CATEGORIES.each_with_index do |name, idx|
      categories.create_with(position: idx).find_or_create_by!(kind: :ingredient, name: name)
    end
    DEFAULT_RECIPE_CATEGORIES.each_with_index do |name, idx|
      categories.create_with(position: idx).find_or_create_by!(kind: :recipe, name: name)
    end
  rescue ActiveRecord::RecordNotUnique
    # Lost a race — other thread seeded the same rows. Fine.
  end

  def bootstrap_default_fixed_cost_categories
    DEFAULT_FIXED_COST_CATEGORIES.each_with_index do |(name, kind), idx|
      fixed_cost_categories.create_with(position: idx).find_or_create_by!(kind: kind, name: name)
    end
  rescue ActiveRecord::RecordNotUnique
    # Lost a race — other thread seeded the same rows. Fine.
  end
end
