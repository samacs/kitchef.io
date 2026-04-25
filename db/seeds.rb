# Realistic demo data for Kitchef.
#
# Two accounts to exercise both UX modes:
#   1. Cocina de Elena — simple mode (flat saleable recipes, ingredients not
#      yet linked to recipes). What a brand-new operator's data looks like.
#   2. Taquería Don Mario — advanced mode (internal base recipes composed of
#      ingredients, saleable recipes composed of both bases and ingredients).
#      What a week-2 operator's data looks like after she's decomposed.
#
# Idempotent. Re-running wipes and recreates both demo accounts.

# Curated sample pools — avoids Faker locale flakiness and keeps the demo
# data on-brand with the PRD's "real Mexican names" rule.
FIRST_NAMES = %w[
  Carmen Lupita Elena Marisol Mariana Rosa Beatriz Alejandra Paula Isabel
  Mario Roberto Carlos Luis Juan Ernesto Héctor Andrés Felipe Rafael
  Adriana Ximena Fernanda Patricia Araceli Guadalupe Gabriela Cristina
  Sofía Valeria Regina Daniela Julieta Elena Rocío
].freeze

LAST_NAMES = %w[
  López Ramírez García Hernández Sánchez Pérez Torres Flores Vargas Reyes
  Morales Jiménez Castillo Romero Mendoza Ortega Ruiz Álvarez Guerrero
  Mendoza Silva Navarro Cortés Chávez Rojas Domínguez Aguilar Campos
].freeze

def sample_first_name      = FIRST_NAMES.sample
def sample_last_name       = LAST_NAMES.sample
def sample_mobile_mx       = "55#{Random.new.rand(10_000_000..99_999_999)}"
def sample_email(first, last, domain: "lvh.me")
  slug = [ first, last.tr(" ", ""), Random.new.rand(10..99) ].join(".").tr("áéíóúñÁÉÍÓÚÑ", "aeiounAEIOUN").downcase
  "#{slug}@#{domain}"
end

# Fetches an image from a remote URL and attaches it to an
# ActiveStorage holder. Gracefully falls back on network errors so a
# `db:seed` run without internet still finishes without aborting — the
# demo accounts just end up photoless for that particular asset. Uses
# a per-URL cache dir (tmp/seed_photos) so re-seeding doesn't refetch.
require "open-uri"
require "fileutils"

def attach_seed_image(record, attachment_name, url:, filename:)
  return if record.send(attachment_name).attached?

  cache_root = Rails.root.join("tmp/seed_photos")
  FileUtils.mkdir_p(cache_root)
  cache_path = cache_root.join(filename)

  unless cache_path.exist?
    URI.open(url, open_timeout: 5, read_timeout: 15) do |remote|
      File.binwrite(cache_path, remote.read)
    end
  end

  record.send(attachment_name).attach(
    io:           File.open(cache_path, "rb"),
    filename:     filename,
    content_type: "image/jpeg"
  )
rescue StandardError => e
  warn "  ⚠  couldn't attach #{attachment_name} to #{record.class.name}(#{record.id}): #{e.class.name}: #{e.message}"
end

# Unsplash CDN URLs curated from tmp/kitchef-design. Each ID is
# image-stable and hotlinkable per Unsplash's API terms. The `w=900`
# + crop params keep download size modest (~60-100 KB per image).
UNSPLASH = ->(id, w: 900) { "https://images.unsplash.com/#{id}?auto=format&fit=crop&w=#{w}&q=80" }

SEED_PHOTO_IDS = {
  # Accounts (cover + logo)
  "elena_cover"         => "photo-1565299624946-b28f40a0ae38",
  "elena_logo"          => "photo-1604908176997-125f25cc6f3d",
  "mario_cover"         => "photo-1565299585323-38d6b0865b47",
  "mario_logo"          => "photo-1552566626-52f8b828add9",
  # Elena's saleable recipes
  "tamal_verde"         => "photo-1625938144755-652e08e359b7",
  "tamal_rojo"          => "photo-1599974579688-8dbdd335c77f",
  "pozole_rojo"         => "photo-1559847844-5315695dadae",
  "enchiladas_suizas"   => "photo-1565299624946-b28f40a0ae38",
  "pastel_tres_leches"  => "photo-1565958011703-44f9829ba187",
  "flan_napolitano"     => "photo-1563729784474-d77dbb933a9e",
  "agua_jamaica"        => "photo-1541167760496-1628856ab772",
  "champurrado"         => "photo-1517578239113-b03992dcdd25",
  # Mario's saleable recipes (names match db/seeds.rb below)
  "tacos_al_pastor"     => "photo-1565299585323-38d6b0865b47",
  "tacos_arrachera"     => "photo-1565299624946-b28f40a0ae38",
  "tacos_pollo"         => "photo-1599974579688-8dbdd335c77f",
  "quesadillas"         => "photo-1625938144755-652e08e359b7",
  "frijoles_charros"    => "photo-1599974579688-8dbdd335c77f",
  "agua_horchata"       => "photo-1541167760496-1628856ab772"
}.freeze

def seed_photo_url(key, w: 900)
  id = SEED_PHOTO_IDS[key]
  return nil if id.blank?
  UNSPLASH.call(id, w: w)
end

puts "==> clearing existing demo data"
# `user.destroy` cascades through owned_account → all account-scoped
# records (see User#detach_from_account + Account has_many :users
# destroy). No need to manually break the circular FK here.
User.where(email_address: %w[elena@lvh.me mario@lvh.me]).find_each(&:destroy)

# ---------------------------------------------------------------------------
# Cocina de Elena — simple mode
# ---------------------------------------------------------------------------
puts "==> Cocina de Elena (simple mode)"

elena = User.create!(
  email_address:     "elena@lvh.me",
  password:          "kitchef2026",
  first_name:        "Elena",
  last_name:         "Ramírez",
  phone:             "5512345678",
  terms_accepted_at: 2.weeks.ago
)

cocina_elena = Account.create!(
  owner: elena,
  name:  "Cocina de Elena",
  time_zone: "America/Mexico_City",
  settings: { use_composable_recipes: false, onboarding_completed: true, default_packaging_cents: 500 },
  branding: {
    palette: "bosque",
    secondary_palette: "terracota",
    hide_kitchef_branding: false
  },
  public_profile: {
    tagline: "Tamales, pasteles y meal-prep · Condesa",
    description: "Recetas de mi abuela, hechas con tiempo. Producto fresco, masa de nixtamal y envolturas traídas de Tabasco.",
    phone: "+52 55 1234 5678",
    whatsapp: "+52 55 1234 5678",
    instagram: "cocinadeelena",
    colonia: "Condesa",
    city: "Ciudad de México",
    fulfillment_types: "pickup,delivery",
    delivery_zones: "Condesa, Roma Norte, Roma Sur, Del Valle, Narvarte",
    payment_notes: "Te contacto por WhatsApp para confirmar el pago (efectivo o transferencia).",
    pickup_reminder_hours: 4,
    ordering_hours: {
      "0" => "closed",
      "1" => { "open" => "09:00", "close" => "18:00" },
      "2" => { "open" => "09:00", "close" => "18:00" },
      "3" => { "open" => "09:00", "close" => "18:00" },
      "4" => { "open" => "09:00", "close" => "18:00" },
      "5" => { "open" => "09:00", "close" => "20:00" },
      "6" => { "open" => "08:00", "close" => "20:00" }
    }.to_json
  }
)
elena.update!(account: cocina_elena)

puts "  …attaching cover + logo"
attach_seed_image(cocina_elena, :cover_photo, url: seed_photo_url("elena_cover", w: 1600), filename: "cocina-elena-cover.jpg")
attach_seed_image(cocina_elena, :logo,        url: seed_photo_url("elena_logo", w: 400),   filename: "cocina-elena-logo.jpg")

Subscription.create!(account: cocina_elena, plan: :free, status: :active)

# Prices reflect late-2026 Mexican retail (Central de Abastos / mercados
# populares pricing for an operator buying by the kilo, not supermarket
# shelf). Rows kept alphabetical within category so the index page lands
# predictably. Suppliers mirror what a real Condesa home-kitchen would
# hit on her Thursday market run.
elena_ingredients = [
  # Abarrotes
  [ "Azúcar estándar",             "kg",   3200, :pantry,  "Bodega Aurrera" ],
  [ "Harina de maíz nixtamalizada", "kg",   4500, :pantry,  "Maseca (bulto de 5kg)" ],
  [ "Hoja de maíz",                "piece",  150, :other,   "Mercado de Medellín" ],
  [ "Jamaica seca",                "kg",  16500, :pantry,   "Mercado de Jamaica" ],
  [ "Manteca de cerdo",            "kg",  12000, :pantry,   "Carnicería El Fogón" ],
  [ "Pasas güeras",                "kg",  11000, :pantry,   "Mercado de San Juan" ],
  [ "Polvo para hornear",          "kg",  28000, :pantry,   "Abarrotes del barrio" ],
  [ "Sal de mar",                  "kg",   3500, :pantry,   "Mercado de San Juan" ],
  # Carnes
  [ "Pechuga de pollo",            "kg",  17500, :meats,    "Pollería La Güera" ],
  [ "Puerco en pulpa",             "kg",  18500, :meats,    "Carnicería El Fogón" ],
  [ "Res molida especial",         "kg",  22000, :meats,    "Carnicería El Fogón" ],
  # Lácteos
  [ "Crema ácida",                 "kg",   8500, :dairy,    "Lácteos Los Volcanes" ],
  [ "Huevo blanco",                "piece", 450, :dairy,    "Huevería Condesa" ],
  [ "Leche entera",                "l",    3200, :dairy,    "Lácteos Los Volcanes" ],
  [ "Mantequilla sin sal",         "kg",  22000, :dairy,    "Lácteos Los Volcanes" ],
  [ "Queso fresco",                "kg",  14500, :dairy,    "Lácteos Los Volcanes" ],
  # Verduras
  [ "Ajo",                         "kg",  14000, :produce,  "Mercado de Jamaica" ],
  [ "Cebolla blanca",              "kg",   2800, :produce,  "Mercado de Medellín" ],
  [ "Chile poblano",               "kg",   5500, :produce,  "Mercado de Medellín" ],
  [ "Chile serrano",               "kg",   6500, :produce,  "Mercado de Medellín" ],
  [ "Cilantro",                    "kg",   8500, :produce,  "Mercado de Medellín" ],
  [ "Tomate rojo",                 "kg",   3800, :produce,  "Mercado de Medellín" ],
  [ "Tomate verde",                "kg",   3500, :produce,  "Mercado de Medellín" ],
  # Frutas
  [ "Fresa",                       "kg",   8500, :produce,  "Mercado de Medellín" ],
  # Especias
  [ "Canela en polvo",             "kg",  55000, :spices,   "Mercado de San Juan" ],
  [ "Comino molido",               "kg",  38000, :spices,   "Mercado de San Juan" ]
]
# Phase 9: `category` is a FK to a per-account Category row. These legacy
# enum symbols map onto the Spanish names the data migration seeded.
INGREDIENT_CATEGORY_NAMES = {
  pantry:  "Abarrotes",
  meats:   "Carnes",
  dairy:   "Lácteos",
  produce: "Frutas y verduras",
  spices:  "Especias",
  other:   "Otros"
}.freeze

RECIPE_CATEGORY_NAMES = {
  mains:    "Platos fuertes",
  starters: "Entradas",
  desserts: "Postres",
  drinks:   "Bebidas",
  bases:    "Bases y preparaciones",
  other:    "Otros"
}.freeze

def ingredient_category_for(account, key)
  account.categories.for_kind(:ingredient).find_by!(name: INGREDIENT_CATEGORY_NAMES.fetch(key))
end

def recipe_category_for(account, key)
  account.categories.for_kind(:recipe).find_by!(name: RECIPE_CATEGORY_NAMES.fetch(key))
end

elena_ingredients.each do |name, unit, cents, cat, supplier|
  cocina_elena.ingredients.create!(
    name: name, unit: unit, unit_cost_cents: cents,
    category: ingredient_category_for(cocina_elena, cat),
    supplier_name: supplier
  )
end

# Phase 9: attach the first-party Supplier + SupplierIngredient records.
# Walks the ingredients we just created, materializes one Supplier per
# distinct `supplier_name`, and defaults a SupplierIngredient row so the
# cost engine cascade (Phase 7 → recomputes on default_supplier change)
# keeps behaving as before.
def seed_default_suppliers!(account)
  account.ingredients.kept.where.not(supplier_name: [ nil, "" ]).find_each do |ing|
    supplier = account.suppliers.kept.find_or_create_by!(name: ing.supplier_name.to_s.strip)
    next if ing.supplier_ingredients.exists?
    ing.supplier_ingredients.create!(
      supplier: supplier,
      unit_cost_cents: ing.unit_cost_cents,
      last_bought_on: Date.current,
      is_default_cost_source: true
    )
  end
end

seed_default_suppliers!(cocina_elena)

# Sale prices reflect what a Condesa home-kitchen operator charges in
# late 2026. Yields are per-unit so the operator can sell by the
# tamal, por porción, por pastel, or por litro. Margins stay hidden
# in simple mode — Elena doesn't see costs until she decomposes.
elena_recipes = [
  [ "Tamal verde",             2800, :mains,    1, "piece",   "tamal_verde" ],
  [ "Tamal rojo de pollo",     2800, :mains,    1, "piece",   "tamal_rojo" ],
  [ "Pozole rojo",            16500, :mains,    1, "serving", "pozole_rojo" ],
  [ "Enchiladas suizas",      16500, :mains,    1, "serving", "enchiladas_suizas" ],
  [ "Pastel de tres leches",  52000, :desserts, 1, "piece",   "pastel_tres_leches" ],
  [ "Flan napolitano",        34000, :desserts, 1, "piece",   "flan_napolitano" ],
  [ "Agua de jamaica (1L)",    5500, :drinks,   1, "l",       "agua_jamaica" ],
  [ "Champurrado (1L)",        6500, :drinks,   1, "l",       "champurrado" ]
]
puts "  …creating recipes + attaching photos"
elena_recipe_list = elena_recipes.map do |name, cents, cat, qty, unit, photo_key|
  # Phase 10 — desserts carry their own packaging (caja de pastel). Give
  # cakes a $35 baseline so the cost tree surfaces it on the recipe
  # detail page and the OrderItem snapshots reflect it at order time.
  recipe_packaging = name.match?(/pastel|flan/i) ? 3500 : 0

  recipe_lead_time = name.match?(/pastel/i) ? 48 : (name.match?(/flan/i) ? 24 : 0)

  recipe = cocina_elena.recipes.create!(
    name: name,
    sale_price_cents: cents,
    is_saleable: true,
    yield_quantity: qty,
    yield_unit: unit,
    category: recipe_category_for(cocina_elena, cat),
    is_published: true,
    target_margin_percent: 60,
    packaging_cents: recipe_packaging,
    lead_time_hours: recipe_lead_time
  )
  attach_seed_image(recipe, :photos,
    url: seed_photo_url(photo_key),
    filename: "#{photo_key}.jpg")
  recipe
end

elena_colonias = [ "Condesa", "Del Valle", "Roma Norte", "Coyoacán", "Polanco",
                   "Chapalita", "Providencia", "Zona Esmeralda",
                   "San Pedro Garza García", "Tlalpan" ]
elena_clients = Array.new(10) do |i|
  cocina_elena.clients.create!(
    first_name: (fname = sample_first_name),
    last_name:  (lname = sample_last_name),
    phone:      sample_mobile_mx,
    email:      sample_email(fname, lname),
    colonia:    elena_colonias[i % elena_colonias.length],
    city:       "Ciudad de México",
    notes:      ("Clienta frecuente, siempre agradece los tamales calientitos." if i.odd?)
  )
end

state_transitions = {
  placed:           [],
  confirmed:        %i[confirm],
  in_production:    %i[confirm start_production],
  ready:            %i[confirm start_production mark_ready],
  delivered:        %i[confirm start_production mark_ready deliver],
  delivered_paid:   %i[confirm start_production mark_ready deliver]
}

15.times do |i|
  client = elena_clients.sample
  order  = cocina_elena.orders.create!(
    client:        client,
    delivery_date: Date.current + (i - 5).days,
    delivery_type: i.even? ? :delivery : :pickup,
    source:        %i[storefront manual whatsapp].sample,
    colonia:       client.colonia,
    city:          client.city,
    delivery_address: (i.even? ? "Calle de prueba #{rand(1..500)}" : nil),
    notes:         ("Sin cilantro, porfa." if i % 4 == 0)
  )
  rand(1..3).times do
    recipe = elena_recipe_list.sample
    order.items.create!(
      recipe:           recipe,
      quantity:         [ 1, 1, 2, 4 ].sample,
      unit_price_cents: recipe.sale_price_cents,
      unit_cost_cents:  (recipe.sale_price_cents * 0.4).to_i
    )
  end
  subtotal = order.items.sum { |it| it.unit_price_cents * it.quantity }
  order.update!(subtotal_cents: subtotal, total_cents: subtotal, balance_cents: subtotal)

  chosen_state = state_transitions.keys.sample
  state_transitions[chosen_state].each { |e| order.send("#{e}!") }
  # `delivered_paid` seeds a delivered order that also has its payment
  # captured — flips `paid_at` without an AASM transition.
  order.mark_paid! if chosen_state == :delivered_paid
end

# ---------------------------------------------------------------------------
# Taquería Don Mario — advanced mode
# ---------------------------------------------------------------------------
puts "==> Taquería Don Mario (advanced mode)"

mario = User.create!(
  email_address:     "mario@lvh.me",
  password:          "kitchef2026",
  first_name:        "Mario",
  last_name:         "Hernández",
  phone:             "5587654321",
  terms_accepted_at: 3.weeks.ago
)

taqueria_mario = Account.create!(
  owner: mario,
  name:  "Taquería Don Mario",
  time_zone: "America/Mexico_City",
  settings: {
    use_composable_recipes: true,
    composable_recipes_unlocked_at: 2.weeks.ago,
    onboarding_completed: true,
    default_packaging_cents: 800
  },
  branding: {
    palette: "terracota",
    secondary_palette: "mostaza",
    hide_kitchef_branding: false
  },
  public_profile: {
    tagline: "Tacos al pastor, arracheras, guisados · Providencia",
    description: "De la barra al carbón. Carne marinada 24h, tortilla recién hecha y salsas de molcajete.",
    phone: "+52 33 8765 4321",
    whatsapp: "+52 33 8765 4321",
    instagram: "taqueriadonmario",
    colonia: "Providencia",
    city: "Guadalajara",
    fulfillment_types: "pickup,delivery",
    delivery_zones: "Providencia, Chapalita, Santa Teresita, Arcos Vallarta, Jardines del Bosque",
    payment_notes: "Anticipo del 50% para asegurar tu pedido. Te mando link de transferencia por WhatsApp.",
    pickup_reminder_hours: 3,
    ordering_hours: {
      "0" => { "open" => "10:00", "close" => "18:00" },
      "1" => "closed",
      "2" => { "open" => "11:00", "close" => "22:00" },
      "3" => { "open" => "11:00", "close" => "22:00" },
      "4" => { "open" => "11:00", "close" => "22:00" },
      "5" => { "open" => "11:00", "close" => "23:00" },
      "6" => { "open" => "10:00", "close" => "23:00" }
    }.to_json
  }
)
mario.update!(account: taqueria_mario)

puts "  …attaching cover + logo"
attach_seed_image(taqueria_mario, :cover_photo, url: seed_photo_url("mario_cover", w: 1600), filename: "taqueria-mario-cover.jpg")
attach_seed_image(taqueria_mario, :logo,        url: seed_photo_url("mario_logo", w: 400),   filename: "taqueria-mario-logo.jpg")

Subscription.create!(account: taqueria_mario, plan: :pro, status: :active)

# Mario's supplier network is wholesale-heavy (Central de Abastos GDL +
# Carnicería Paty for the proteins). Prices reflect wholesale-by-the-
# kilo rates a taquería with daily volume would actually pay.
mario_ingredients = {
  "Harina de maíz nixtamalizada" => [ "kg",   4500, :pantry,  "Maseca (bulto de 10kg)" ],
  "Manteca de cerdo"             => [ "kg",  12000, :pantry,  "Carnicería Paty" ],
  "Sal de mar"                   => [ "kg",   3500, :pantry,  "Abarrotes Providencia" ],
  "Aceite de maíz"               => [ "l",    5200, :pantry,  "Abarrotes Providencia" ],
  "Frijol bayo"                  => [ "kg",   4500, :pantry,  "Central de Abastos" ],
  "Carne al pastor marinada"     => [ "kg",  24000, :meats,   "Carnicería Paty" ],
  "Arrachera"                    => [ "kg",  38000, :meats,   "Carnicería Paty" ],
  "Pechuga de pollo"             => [ "kg",  17500, :meats,   "Pollería del Centro" ],
  "Queso Oaxaca"                 => [ "kg",  18500, :dairy,   "Lácteos El Rodeo" ],
  "Tomate verde"                 => [ "kg",   3500, :produce, "Central de Abastos" ],
  "Tomate rojo"                  => [ "kg",   3800, :produce, "Central de Abastos" ],
  "Chile serrano"                => [ "kg",   6500, :produce, "Central de Abastos" ],
  "Chile de árbol"               => [ "kg",  11500, :produce, "Central de Abastos" ],
  "Cebolla blanca"               => [ "kg",   2800, :produce, "Central de Abastos" ],
  "Cilantro"                     => [ "kg",   8500, :produce, "Central de Abastos" ],
  "Piña"                         => [ "kg",   3200, :produce, "Central de Abastos" ],
  "Ajo"                          => [ "kg",  14000, :produce, "Central de Abastos" ],
  "Tortilla de harina"           => [ "piece", 150, :pantry,  "Abarrotes Providencia" ],
  "Aguacate"                     => [ "kg",  6500, :produce, "Central de Abastos" ],
  "Limón"                        => [ "kg",  3800, :produce, "Central de Abastos" ]
}
mario_ing = {}
mario_ingredients.each do |name, (unit, cents, cat, supplier)|
  mario_ing[name] = taqueria_mario.ingredients.create!(
    name: name, unit: unit, unit_cost_cents: cents,
    category: ingredient_category_for(taqueria_mario, cat),
    supplier_name: supplier
  )
end

seed_default_suppliers!(taqueria_mario)

# Mario shops at two places for some ingredients — give a handful a
# secondary, cheaper alternative so the "hacerlo default?" nudge has
# something to surface in demos.
mario_alt_supplier = taqueria_mario.suppliers.kept.find_or_create_by!(name: "Costco Providencia")
{
  "Harina de maíz nixtamalizada" => 4200,   # vs 4500 at Maseca
  "Manteca de cerdo"             => 11500,  # vs 12000 default
  "Pechuga de pollo"             => 16800   # vs 17500 default
}.each do |name, cents|
  ing = mario_ing[name]
  next unless ing
  ing.supplier_ingredients.find_or_create_by!(supplier: mario_alt_supplier) do |si|
    si.unit_cost_cents = cents
    si.last_bought_on = Date.current - 5.days
    si.is_default_cost_source = false
  end
end

mario_bases_cat = recipe_category_for(taqueria_mario, :bases)
mario_mains_cat = recipe_category_for(taqueria_mario, :mains)

masa = taqueria_mario.recipes.create!(
  name: "Masa fresca",
  is_saleable: false,
  yield_quantity: 1800, yield_unit: "g",
  category: mario_bases_cat
)
[
  [ mario_ing["Harina de maíz nixtamalizada"], 1000, "g" ],
  [ mario_ing["Manteca de cerdo"],              200, "g" ],
  [ mario_ing["Sal de mar"],                     15, "g" ]
].each { |ing, qty, unit| masa.components.create!(componentable: ing, quantity: qty, unit: unit) }

salsa_verde = taqueria_mario.recipes.create!(
  name: "Salsa verde",
  is_saleable: false,
  yield_quantity: 500, yield_unit: "ml",
  category: mario_bases_cat
)
[
  [ mario_ing["Tomate verde"],   400, "g" ],
  [ mario_ing["Chile serrano"],   30, "g" ],
  [ mario_ing["Cebolla blanca"],  40, "g" ],
  [ mario_ing["Cilantro"],        10, "g" ]
].each { |ing, qty, unit| salsa_verde.components.create!(componentable: ing, quantity: qty, unit: unit) }

salsa_roja = taqueria_mario.recipes.create!(
  name: "Salsa roja",
  is_saleable: false,
  yield_quantity: 500, yield_unit: "ml",
  category: mario_bases_cat
)
[
  [ mario_ing["Tomate rojo"],       400, "g" ],
  [ mario_ing["Chile de árbol"],     20, "g" ],
  [ mario_ing["Cebolla blanca"],     40, "g" ],
  [ mario_ing["Ajo"],                10, "g" ]
].each { |ing, qty, unit| salsa_roja.components.create!(componentable: ing, quantity: qty, unit: unit) }

frijoles = taqueria_mario.recipes.create!(
  name: "Frijoles refritos",
  is_saleable: false,
  yield_quantity: 1000, yield_unit: "g",
  category: mario_bases_cat
)
[
  [ mario_ing["Frijol bayo"],      400, "g" ],
  [ mario_ing["Manteca de cerdo"], 100, "g" ],
  [ mario_ing["Cebolla blanca"],    60, "g" ]
].each { |ing, qty, unit| frijoles.components.create!(componentable: ing, quantity: qty, unit: unit) }

# Saleable recipes calibrated to land each dish right around Mario's
# 60–65% target margin at 2026 Providencia prices. Qty per taco mirrors
# a real taquería portion (45–50g of carne, not a full sit-down serving).
def build_taco(account, name:, carne:, carne_qty:, salsa:, salsa_qty:, price_cents:, masa:, mario_ing:,
               target_margin_percent: 65)
  rec = account.recipes.create!(
    name: name,
    sale_price_cents: price_cents,
    is_saleable: true,
    is_published: true,
    yield_quantity: 1, yield_unit: "piece",
    category: recipe_category_for(account, :mains),
    target_margin_percent: target_margin_percent
  )
  rec.components.create!(componentable: masa,  quantity: 28,        unit: "g")
  rec.components.create!(componentable: carne, quantity: carne_qty, unit: "g")
  rec.components.create!(componentable: salsa, quantity: salsa_qty, unit: "ml")
  rec.components.create!(componentable: mario_ing["Cebolla blanca"], quantity: 6, unit: "g")
  rec.components.create!(componentable: mario_ing["Cilantro"],       quantity: 3, unit: "g")
  rec
end

# Taco al pastor — flagship. 50g of marinated pastor, salsa verde.
#   Cost: ~$14.05, sale $35 → ~60% margin.
build_taco(taqueria_mario, name: "Taco al pastor",
  carne: mario_ing["Carne al pastor marinada"], carne_qty: 50,
  salsa: salsa_verde, salsa_qty: 15, price_cents: 3500,
  masa: masa, mario_ing: mario_ing)

# Taco de asada (arrachera) — premium protein, salsa roja, slightly tighter margin.
#   Cost: ~$21.10, sale $48 → ~56% margin (the upsell pays for itself).
build_taco(taqueria_mario, name: "Taco de asada",
  carne: mario_ing["Arrachera"], carne_qty: 50,
  salsa: salsa_roja,  salsa_qty: 15, price_cents: 4800,
  masa: masa, mario_ing: mario_ing,
  target_margin_percent: 60)

# Taco de pollo — budget option. Salsa verde. Healthy margin.
#   Cost: ~$10.80, sale $30 → ~64% margin.
build_taco(taqueria_mario, name: "Taco de pollo",
  carne: mario_ing["Pechuga de pollo"], carne_qty: 50,
  salsa: salsa_verde, salsa_qty: 15, price_cents: 3000,
  masa: masa, mario_ing: mario_ing)

# Quesadilla — bigger masa portion, 60g queso Oaxaca.
#   Cost: ~$15.10, sale $42 → ~64% margin.
quesadilla = taqueria_mario.recipes.create!(
  name: "Quesadilla",
  sale_price_cents: 4200, is_saleable: true, is_published: true,
  yield_quantity: 1, yield_unit: "piece",
  category: mario_mains_cat, target_margin_percent: 65
)
quesadilla.components.create!(componentable: masa,                      quantity: 80, unit: "g")
quesadilla.components.create!(componentable: mario_ing["Queso Oaxaca"], quantity: 60, unit: "g")
quesadilla.components.create!(componentable: salsa_verde,               quantity: 20, unit: "ml")

# Sope con frijol — thicker masa base + frijoles refritos + queso.
#   Cost: ~$11.10, sale $32 → ~65% margin.
sope = taqueria_mario.recipes.create!(
  name: "Sope con frijol",
  sale_price_cents: 3200, is_saleable: true, is_published: true,
  yield_quantity: 1, yield_unit: "piece",
  category: mario_mains_cat, target_margin_percent: 65
)
sope.components.create!(componentable: masa,                        quantity: 100, unit: "g")
sope.components.create!(componentable: frijoles,                    quantity:  80, unit: "g")
sope.components.create!(componentable: salsa_roja,                  quantity:  20, unit: "ml")
sope.components.create!(componentable: mario_ing["Queso Oaxaca"],   quantity:  20, unit: "g")

# Gringa al pastor — flour-style with 75g pastor + queso + piña.
#   Cost: ~$34.50, sale $95 → ~64% margin.
gringa = taqueria_mario.recipes.create!(
  name: "Gringa al pastor",
  sale_price_cents: 9500, is_saleable: true, is_published: true,
  yield_quantity: 1, yield_unit: "piece",
  category: mario_mains_cat, target_margin_percent: 65
)
gringa.components.create!(componentable: masa,                                  quantity: 120, unit: "g")
gringa.components.create!(componentable: mario_ing["Carne al pastor marinada"], quantity:  75, unit: "g")
gringa.components.create!(componentable: mario_ing["Queso Oaxaca"],             quantity:  60, unit: "g")
gringa.components.create!(componentable: mario_ing["Piña"],                     quantity:  25, unit: "g")

mario_saleable = taqueria_mario.recipes.saleable.to_a

# Pre-populate cost caches so the recetario and cost-tree pages land
# with real numbers on first visit, instead of waiting on Sidekiq to
# drain the post-seed queue. CostCalculator persists `cost_cents_cached`
# bottom-up, so running it on each saleable recipe also fills every
# sub-recipe it reaches.
puts "  …warming cost caches"
mario_saleable.each { |r| Recipes::CostCalculator.for(recipe: r) }

# Attach a photo to each saleable Mario recipe by name match. The keys
# below correspond to SEED_PHOTO_IDS entries — names drifting from
# those photo keys would log a warning and the recipe ends up
# photoless (which simply hides the storefront's "Publicar" CTA until
# the operator uploads one manually).
mario_photo_keys = {
  "Taco al pastor"    => "tacos_al_pastor",
  "Taco de asada"     => "tacos_arrachera",
  "Taco de pollo"     => "tacos_pollo",
  "Quesadilla"        => "quesadillas",
  "Sope con frijol"   => "frijoles_charros",
  "Gringa al pastor"  => "tacos_al_pastor"
}
puts "  …attaching recipe photos"
mario_saleable.each do |recipe|
  key = mario_photo_keys[recipe.name]
  next unless key
  attach_seed_image(recipe, :photos, url: seed_photo_url(key), filename: "#{key}-#{recipe.id}.jpg")
end

# Phase 9: a handful of realistic purchases so the gastos lane in
# /reports/finance lights up on demo. Spread across the last 3 weeks.
puts "  …seeding Mario purchase ledger"
central_de_abastos = taqueria_mario.suppliers.kept.find_by(name: "Central de Abastos")
carniceria_paty    = taqueria_mario.suppliers.kept.find_by(name: "Carnicería Paty")
[
  [ 18.days.ago, central_de_abastos, [
      [ "Tomate verde",    "3",   "kg", "35.00" ],
      [ "Cebolla blanca",  "2",   "kg", "28.00" ],
      [ "Chile serrano",   "0.5", "kg", "65.00" ],
      [ "Ajo",             "0.3", "kg", "140.00" ]
    ] ],
  [ 12.days.ago, carniceria_paty, [
      [ "Carne al pastor marinada", "2",   "kg", "245.00" ],
      [ "Arrachera",                "1.5", "kg", "380.00" ]
    ] ],
  [ 5.days.ago, central_de_abastos, [
      [ "Tomate rojo",     "4",   "kg", "38.00" ],
      [ "Cilantro",        "0.4", "kg", "85.00" ],
      [ "Piña",            "2",   "kg", "32.00" ]
    ] ],
  [ 2.days.ago, carniceria_paty, [
      [ "Pechuga de pollo", "2.5", "kg", "180.00" ]
    ] ]
].each do |days, supplier, lines|
  result = Purchases::Create.call(
    account: taqueria_mario,
    params: {
      purchased_on: days.to_date,
      supplier_id: supplier&.id,
      items_attributes: lines.each_with_index.map do |(name, qty, unit, cost), i|
        ing = mario_ing[name]
        next nil unless ing
        [ i.to_s, { ingredient_id: ing.id, quantity: qty, unit: unit, unit_cost: cost } ]
      end.compact.to_h
    }
  )
  puts "    purchase #{days.to_date.iso8601} failed: #{result.errors.full_messages}" unless result.success?
end

mario_colonias = [ "Condesa", "Del Valle", "Polanco", "Coyoacán", "Narvarte",
                   "Roma Sur", "Santa Fe", "Tlalpan", "Insurgentes", "Xoco",
                   "Acapulco" ]
mario_clients = Array.new(15) do |i|
  taqueria_mario.clients.create!(
    first_name: (fname = sample_first_name),
    last_name:  (lname = sample_last_name),
    phone:      sample_mobile_mx,
    email:      sample_email(fname, lname),
    colonia:    mario_colonias[i % mario_colonias.length],
    city:       "Ciudad de México"
  )
end

25.times do |i|
  client = mario_clients.sample
  order  = taqueria_mario.orders.create!(
    client:        client,
    delivery_date: Date.current + (i - 8).days,
    delivery_type: i.even? ? :delivery : :pickup,
    source:        %i[storefront manual whatsapp instagram].sample,
    colonia:       client.colonia,
    city:          client.city,
    delivery_address: (i.even? ? "Av. demo #{rand(1..800)}" : nil)
  )
  rand(2..5).times do
    recipe = mario_saleable.sample
    order.items.create!(
      recipe:           recipe,
      quantity:         [ 1, 2, 2, 3, 4, 6 ].sample,
      unit_price_cents: recipe.sale_price_cents,
      # Mario's recipes are decomposed, so snapshot the real cached cost.
      # Falls back to a 35% estimate only if the cache is somehow empty.
      unit_cost_cents:  recipe.cost_cents_cached.presence || (recipe.sale_price_cents * 0.35).to_i
    )
  end
  subtotal = order.items.sum { |it| it.unit_price_cents * it.quantity }
  order.update!(subtotal_cents: subtotal, total_cents: subtotal, balance_cents: subtotal)

  chosen_state = state_transitions.keys.sample
  state_transitions[chosen_state].each { |e| order.send("#{e}!") }
  # `delivered_paid` seeds a delivered order that also has its payment
  # captured — flips `paid_at` without an AASM transition.
  order.mark_paid! if chosen_state == :delivered_paid
end

# ---------------------------------------------------------------------------
# Phase 10 — fixed costs (renta, gas, plataformas)
# ---------------------------------------------------------------------------
puts "==> seeding fixed costs"

def seed_fixed_cost!(account:, category_name:, amount_cents:, recurrence:, start_date:, end_date: nil, cost_per_pedido_cents: nil, notes: nil)
  category = account.fixed_cost_categories.kept.find_by(name: category_name)
  return unless category
  account.fixed_costs.create!(
    fixed_cost_category:   category,
    amount_cents:          amount_cents,
    recurrence:            recurrence,
    start_date:            start_date,
    end_date:              end_date,
    cost_per_pedido_cents: cost_per_pedido_cents,
    notes:                 notes
  )
end

# Mario — full kit. He's the reference advanced operator, so he has
# the renta and the platform commission already logged.
seed_fixed_cost!(
  account:       taqueria_mario,
  category_name: "Renta",
  amount_cents:  1_500_000,  # $15,000
  recurrence:    :monthly,
  start_date:    Date.new(2026, 4, 1),
  notes:         "Local completo — contrato anual."
)
seed_fixed_cost!(
  account:       taqueria_mario,
  category_name: "Gas y servicios",
  amount_cents:  200_000,    # $2,000
  recurrence:    :monthly,
  start_date:    Date.new(2026, 4, 1)
)
seed_fixed_cost!(
  account:       taqueria_mario,
  category_name: "Plataformas",
  amount_cents:  50_000,     # $500
  recurrence:    :weekly,
  start_date:    Date.new(2026, 4, 1),
  notes:         "Paquete Didi Food."
)

# Elena — moved mid-month, smaller operation. Single rent entry to
# exercise mid-period start_date in the allocation math.
seed_fixed_cost!(
  account:       cocina_elena,
  category_name: "Renta",
  amount_cents:  800_000,    # $8,000
  recurrence:    :monthly,
  start_date:    Date.new(2026, 3, 15)
)

# ---------------------------------------------------------------------------
# Phase 11 — recipe option groups (personalización de platillos)
# ---------------------------------------------------------------------------
puts "==> seeding recipe option groups"

# Clean stale groups from previous runs / manual testing
RecipeOptionGroup.destroy_all

# ── Elena: Pastel de tres leches ──────────────────────────────────────────
# Matches the "Lupita repostería" design reference — size radio with
# negative/positive deltas, flavor radio, meringue color swatch, extras
# with subs and prices, and a dedication textarea.
pastel = cocina_elena.recipes.kept.saleable.find_by(name: "Pastel de tres leches")
if pastel
  # Tamaño — base price is 20-portion ($520). Smaller is cheaper, larger more.
  size_g = pastel.option_groups.create!(
    account: cocina_elena, label: "Tamaño", kind: :radio, required: true, position: 0
  )
  size_g.options.create!(label: "10 porciones", sub: "ideal individual",     price_delta_cents: -18000, position: 0)
  size_g.options.create!(label: "20 porciones", sub: "cumpleaños pequeño",   price_delta_cents: 0,      position: 1, is_default: true)
  size_g.options.create!(label: "30 porciones", sub: "fiesta",              price_delta_cents: 28000,  position: 2)

  # Relleno
  relleno_g = pastel.option_groups.create!(
    account: cocina_elena, label: "Relleno", kind: :radio, required: true, position: 1
  )
  relleno_g.options.create!(label: "Fresa natural",             price_delta_cents: 0,    position: 0, is_default: true)
  relleno_g.options.create!(label: "Durazno en almíbar",        price_delta_cents: 0,    position: 1)
  relleno_g.options.create!(label: "Piña caramelizada",         price_delta_cents: 0,    position: 2)
  relleno_g.options.create!(label: "Mixto (fresa + durazno)",   price_delta_cents: 4000, position: 3)

  # Color del merengue — swatch with group subtitle
  color_g = pastel.option_groups.create!(
    account: cocina_elena, label: "Color del merengue", sub: "Personalización gratuita",
    kind: :swatch, required: false, position: 2
  )
  color_g.options.create!(label: "Blanco",      color_hex: "#F9F5ED", position: 0, is_default: true, price_delta_cents: 0)
  color_g.options.create!(label: "Rosa pastel", color_hex: "#F5B8C0", position: 1, price_delta_cents: 0)
  color_g.options.create!(label: "Durazno",     color_hex: "#F6BE8B", position: 2, price_delta_cents: 0)
  color_g.options.create!(label: "Menta",       color_hex: "#B8DCC4", position: 3, price_delta_cents: 0)
  color_g.options.create!(label: "Azul cielo",  color_hex: "#B8CEE4", position: 4, price_delta_cents: 0)
  color_g.options.create!(label: "Amarillo",    color_hex: "#F4DB8D", position: 5, price_delta_cents: 0)
  color_g.options.create!(label: "Lavanda",     color_hex: "#CFC2E4", position: 6, price_delta_cents: 0)

  # Extras — each with subtitle and price
  extras_g = pastel.option_groups.create!(
    account: cocina_elena, label: "Extras", kind: :check, required: false, position: 3
  )
  extras_g.options.create!(label: "Velas de número",     sub: "paq. 1–99",           price_delta_cents: 3500,  position: 0)
  extras_g.options.create!(label: "Adorno floral",       sub: "flores comestibles",  price_delta_cents: 12000, position: 1)
  extras_g.options.create!(label: "Caja de regalo",      sub: "kraft con moño",      price_delta_cents: 6500,  position: 2)
  extras_g.options.create!(label: "Letrero en acrílico", sub: "hasta 20 letras",     price_delta_cents: 9000,  position: 3)

  # Dedicatoria — textarea
  pastel.option_groups.create!(
    account: cocina_elena, label: "Dedicatoria sobre el pastel",
    sub: "Hasta 30 letras · en fondant.",
    kind: :textarea, required: false, position: 4, max_length: 30
  )

  # Mark fresa as removable component (if decomposed)
  pastel.components.where(componentable_type: "Ingredient").each do |comp|
    name = comp.componentable&.name.to_s.downcase
    comp.update!(is_removable: true) if name.include?("fresa")
  end

  puts "  Elena: Pastel → #{pastel.option_groups.count} groups"
end

# ── Elena: Enchiladas suizas ──────────────────────────────────────────────
# Salsa choice, toppings, extras with prices, removable ingredients
enchiladas = cocina_elena.recipes.kept.saleable.find_by(name: "Enchiladas suizas")
if enchiladas
  salsa_g = enchiladas.option_groups.create!(
    account: cocina_elena, label: "Tipo de salsa", kind: :radio, required: true, position: 0
  )
  salsa_g.options.create!(label: "Salsa verde suiza",    price_delta_cents: 0,    position: 0, is_default: true)
  salsa_g.options.create!(label: "Salsa roja",           price_delta_cents: 0,    position: 1)
  salsa_g.options.create!(label: "Salsa de chipotle",    sub: "picante medio", price_delta_cents: 1500, position: 2)

  extras_g = enchiladas.option_groups.create!(
    account: cocina_elena, label: "Extras", kind: :check, required: false, position: 1
  )
  extras_g.options.create!(label: "Crema extra",           sub: "porción doble",    price_delta_cents: 1500, position: 0)
  extras_g.options.create!(label: "Queso gratinado",       sub: "Oaxaca y manchego", price_delta_cents: 2500, position: 1)
  extras_g.options.create!(label: "Aguacate",              sub: "medio aguacate",   price_delta_cents: 3000, position: 2)
  extras_g.options.create!(label: "Arroz rojo",            sub: "porción extra",    price_delta_cents: 1500, position: 3)

  enchiladas.option_groups.create!(
    account: cocina_elena, label: "Notas para la cocinera",
    sub: "Alergias, nivel de picante, etc.",
    kind: :textarea, required: false, position: 2, max_length: 200
  )

  enchiladas.components.where(componentable_type: "Ingredient").each do |comp|
    name = comp.componentable&.name.to_s.downcase
    comp.update!(is_removable: true) if name.include?("cebolla") || name.include?("crema") || name.include?("cilantro")
  end
  puts "  Elena: Enchiladas → #{enchiladas.option_groups.count} groups"
end

# ── Elena: Pozole rojo ────────────────────────────────────────────────────
# Size radio + garnish extras + spice level
pozole = cocina_elena.recipes.kept.saleable.find_by(name: "Pozole rojo")
if pozole
  size_g = pozole.option_groups.create!(
    account: cocina_elena, label: "Tamaño", kind: :radio, required: true, position: 0
  )
  size_g.options.create!(label: "Porción individual", sub: "~500ml",  price_delta_cents: 0,     position: 0, is_default: true)
  size_g.options.create!(label: "Para 2–3 personas",  sub: "1 litro", price_delta_cents: 10000, position: 1)

  spice_g = pozole.option_groups.create!(
    account: cocina_elena, label: "Nivel de picante", kind: :radio, required: false, position: 1
  )
  spice_g.options.create!(label: "Sin picante",  price_delta_cents: 0, position: 0)
  spice_g.options.create!(label: "Medio",        price_delta_cents: 0, position: 1, is_default: true)
  spice_g.options.create!(label: "Picosito",     price_delta_cents: 0, position: 2)

  garnish_g = pozole.option_groups.create!(
    account: cocina_elena, label: "Guarniciones extra", kind: :check, required: false, position: 2
  )
  garnish_g.options.create!(label: "Tostadas extra",  sub: "6 piezas",      price_delta_cents: 1500, position: 0)
  garnish_g.options.create!(label: "Aguacate",        sub: "medio aguacate", price_delta_cents: 2500, position: 1)
  garnish_g.options.create!(label: "Chicharrón",      sub: "porción extra",  price_delta_cents: 2000, position: 2)

  puts "  Elena: Pozole → #{pozole.option_groups.count} groups"
end

# ── Mario: Taco al pastor ────────────────────────────────────────────────
# Tortilla choice (maíz vs harina), salsa, extras with descriptions,
# and removable ingredients (cilantro, cebolla, piña).
taco_pastor = taqueria_mario.recipes.kept.saleable.find_by(name: "Taco al pastor")
if taco_pastor
  tortilla_g = taco_pastor.option_groups.create!(
    account: taqueria_mario, label: "Tortilla", kind: :radio, required: true, position: 0
  )
  tortilla_g.options.create!(label: "Maíz",           sub: "nixtamalizada, hecha a mano", price_delta_cents: 0, position: 0, is_default: true)
  tortilla_g.options.create!(label: "Harina",          sub: "suave y esponjosa",          price_delta_cents: 300, position: 1)

  salsa_g = taco_pastor.option_groups.create!(
    account: taqueria_mario, label: "Salsa", kind: :radio, required: false, position: 1
  )
  salsa_g.options.create!(label: "Verde",       sub: "tomatillo + serrano",    price_delta_cents: 0,   position: 0, is_default: true)
  salsa_g.options.create!(label: "Roja",        sub: "chile de árbol tatemado", price_delta_cents: 0,   position: 1)
  salsa_g.options.create!(label: "Habanero",    sub: "muy picante 🌶️",        price_delta_cents: 500, position: 2)
  salsa_g.options.create!(label: "Sin salsa",                                   price_delta_cents: 0,   position: 3)

  extras_g = taco_pastor.option_groups.create!(
    account: taqueria_mario, label: "Extras", kind: :check, required: false, position: 2
  )
  extras_g.options.create!(label: "Queso Oaxaca",   sub: "fundido sobre el taco",  price_delta_cents: 1500, position: 0)
  extras_g.options.create!(label: "Piña extra",     sub: "doble porción caramelizada", price_delta_cents: 800,  position: 1)
  extras_g.options.create!(label: "Guacamole",      sub: "hecho al momento",       price_delta_cents: 2000, position: 2)
  extras_g.options.create!(label: "Limón extra",    sub: "2 mitades",              price_delta_cents: 0,    position: 3)

  taco_pastor.components.where(componentable_type: "Ingredient").each do |comp|
    name = comp.componentable&.name.to_s.downcase
    comp.update!(is_removable: true) if name.include?("cebolla") || name.include?("cilantro") || name.include?("piña")
  end
  puts "  Mario: Taco al pastor → #{taco_pastor.option_groups.count} groups"
end

# ── Mario: Taco de asada ─────────────────────────────────────────────────
# Same tortilla/salsa pattern as pastor, different extras
taco_asada = taqueria_mario.recipes.kept.saleable.find_by(name: "Taco de asada")
if taco_asada
  tortilla_g = taco_asada.option_groups.create!(
    account: taqueria_mario, label: "Tortilla", kind: :radio, required: true, position: 0
  )
  tortilla_g.options.create!(label: "Maíz",   sub: "nixtamalizada", price_delta_cents: 0,   position: 0, is_default: true)
  tortilla_g.options.create!(label: "Harina", sub: "estilo norteño", price_delta_cents: 300, position: 1)

  salsa_g = taco_asada.option_groups.create!(
    account: taqueria_mario, label: "Salsa", kind: :radio, required: false, position: 1
  )
  salsa_g.options.create!(label: "Roja",        price_delta_cents: 0,   position: 0, is_default: true)
  salsa_g.options.create!(label: "Verde",       price_delta_cents: 0,   position: 1)
  salsa_g.options.create!(label: "Guacamole",   sub: "en lugar de salsa", price_delta_cents: 1500, position: 2)
  salsa_g.options.create!(label: "Sin salsa",   price_delta_cents: 0,   position: 3)

  extras_g = taco_asada.option_groups.create!(
    account: taqueria_mario, label: "Extras", kind: :check, required: false, position: 2
  )
  extras_g.options.create!(label: "Queso Oaxaca", sub: "fundido",         price_delta_cents: 1500, position: 0)
  extras_g.options.create!(label: "Nopales",      sub: "asados a la plancha", price_delta_cents: 1000, position: 1)
  extras_g.options.create!(label: "Cebollitas",   sub: "cambray asadas",  price_delta_cents: 800,  position: 2)

  taco_asada.components.where(componentable_type: "Ingredient").each do |comp|
    name = comp.componentable&.name.to_s.downcase
    comp.update!(is_removable: true) if name.include?("cebolla") || name.include?("cilantro")
  end
  puts "  Mario: Taco de asada → #{taco_asada.option_groups.count} groups"
end

# ── Mario: Quesadilla ────────────────────────────────────────────────────
# Cheese type swatch + protein add-on + extras
quesadilla = taqueria_mario.recipes.kept.saleable.find_by(name: "Quesadilla")
if quesadilla
  cheese_g = quesadilla.option_groups.create!(
    account: taqueria_mario, label: "Tipo de queso", sub: "Todos derriten perfecto",
    kind: :swatch, required: true, position: 0
  )
  cheese_g.options.create!(label: "Oaxaca",    color_hex: "#FFF8E7", price_delta_cents: 0,    position: 0, is_default: true)
  cheese_g.options.create!(label: "Manchego",  color_hex: "#F5DEB3", price_delta_cents: 1000, position: 1)
  cheese_g.options.create!(label: "Chihuahua", color_hex: "#FAEBD7", price_delta_cents: 800,  position: 2)
  cheese_g.options.create!(label: "Mixto",     color_hex: "#F0E4C8", price_delta_cents: 500,  position: 3, sub: "Oaxaca + manchego")

  protein_g = quesadilla.option_groups.create!(
    account: taqueria_mario, label: "Proteína", sub: "Agrega proteína a tu quesadilla",
    kind: :radio, required: false, position: 1
  )
  protein_g.options.create!(label: "Sin proteína",  price_delta_cents: 0,    position: 0, is_default: true)
  protein_g.options.create!(label: "Pastor",        sub: "marinada 24h",  price_delta_cents: 2500, position: 1)
  protein_g.options.create!(label: "Arrachera",     sub: "corte premium", price_delta_cents: 3500, position: 2)
  protein_g.options.create!(label: "Pollo",         sub: "a la plancha",  price_delta_cents: 2000, position: 3)

  extras_g = quesadilla.option_groups.create!(
    account: taqueria_mario, label: "Acompañar con", kind: :check, required: false, position: 2
  )
  extras_g.options.create!(label: "Guacamole",       sub: "porción individual",   price_delta_cents: 2000, position: 0)
  extras_g.options.create!(label: "Frijoles refritos", sub: "con queso encima",    price_delta_cents: 1200, position: 1)
  extras_g.options.create!(label: "Rajas con crema",  sub: "chile poblano",       price_delta_cents: 1500, position: 2)

  puts "  Mario: Quesadilla → #{quesadilla.option_groups.count} groups"
end

# ── Mario: Gringa al pastor ───────────────────────────────────────────────
# Gringas always use flour tortilla — no tortilla choice needed. Extras
# and removable piña showcase a different customization pattern.
gringa = taqueria_mario.recipes.kept.saleable.find_by(name: "Gringa al pastor")
if gringa
  extras_g = gringa.option_groups.create!(
    account: taqueria_mario, label: "Extras", kind: :check, required: false, position: 0
  )
  extras_g.options.create!(label: "Doble queso",    sub: "extra Oaxaca fundido", price_delta_cents: 2000, position: 0)
  extras_g.options.create!(label: "Guacamole",      sub: "hecho al momento",    price_delta_cents: 2000, position: 1)
  extras_g.options.create!(label: "Champiñones",    sub: "salteados con ajo",   price_delta_cents: 1500, position: 2)

  gringa.option_groups.create!(
    account: taqueria_mario, label: "Notas",
    sub: "Instrucciones especiales para tu gringa.",
    kind: :textarea, required: false, position: 1, max_length: 150
  )

  gringa.components.where(componentable_type: "Ingredient").each do |comp|
    name = comp.componentable&.name.to_s.downcase
    comp.update!(is_removable: true) if name.include?("piña")
  end
  puts "  Mario: Gringa → #{gringa.option_groups.count} groups"
end

# ── Mario: Sope con frijol ───────────────────────────────────────────────
# Toppings radio + extras
sope = taqueria_mario.recipes.kept.saleable.find_by(name: "Sope con frijol")
if sope
  topping_g = sope.option_groups.create!(
    account: taqueria_mario, label: "Topping de proteína", kind: :radio, required: false, position: 0
  )
  topping_g.options.create!(label: "Solo frijol",     sub: "clásico",              price_delta_cents: 0,    position: 0, is_default: true)
  topping_g.options.create!(label: "Con pollo",        sub: "deshebrado",           price_delta_cents: 1800, position: 1)
  topping_g.options.create!(label: "Con pastor",       sub: "marinada al trompo",   price_delta_cents: 2000, position: 2)
  topping_g.options.create!(label: "Con arrachera",    sub: "corte fino",           price_delta_cents: 3000, position: 3)

  extras_g = sope.option_groups.create!(
    account: taqueria_mario, label: "Extras", kind: :check, required: false, position: 1
  )
  extras_g.options.create!(label: "Crema",       sub: "porción extra",         price_delta_cents: 500,  position: 0)
  extras_g.options.create!(label: "Queso fresco", sub: "desmoronado",          price_delta_cents: 800,  position: 1)
  extras_g.options.create!(label: "Aguacate",    sub: "rebanada",              price_delta_cents: 1500, position: 2)

  sope.components.where(componentable_type: "Ingredient").each do |comp|
    name = comp.componentable&.name.to_s.downcase
    comp.update!(is_removable: true) if name.include?("queso")
  end
  puts "  Mario: Sope → #{sope.option_groups.count} groups"
end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
puts "\n==> done"
[ cocina_elena, taqueria_mario ].each do |a|
  puts "  #{a.name} (#{a.slug})"
  puts "    ingredients: #{a.ingredients.count}"
  puts "    recipes:     saleable=#{a.recipes.saleable.count}, internal=#{a.recipes.internal.count}"
  puts "    clients:     #{a.clients.count}"
  puts "    orders:      #{a.orders.count} (#{a.orders.group(:state).count})"
  puts "    suppliers:   #{a.suppliers.count}"
  puts "    purchases:   #{a.purchases.count}"
  puts "    fixed costs: #{a.fixed_costs.count} (#{a.fixed_cost_categories.count} categories)"
  puts "    option groups: #{RecipeOptionGroup.where(account: a).count}"
end
