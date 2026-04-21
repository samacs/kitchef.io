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
  settings: { use_composable_recipes: false, onboarding_completed: true },
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

elena_ingredients = [
  [ "Harina de maíz nixtamalizada", "kg",  2400, :pantry ],
  [ "Manteca de cerdo",             "kg",  8500, :pantry ],
  [ "Azúcar",                       "kg",  2800, :pantry ],
  [ "Sal",                          "kg",  1500, :pantry ],
  [ "Polvo para hornear",           "kg", 12000, :pantry ],
  [ "Pechuga de pollo",             "kg", 14500, :meats ],
  [ "Puerco en pulpa",              "kg", 13800, :meats ],
  [ "Res molida",                   "kg", 16500, :meats ],
  [ "Leche entera",                 "l",   2400, :dairy ],
  [ "Crema ácida",                  "kg",  6800, :dairy ],
  [ "Queso fresco",                 "kg",  9800, :dairy ],
  [ "Mantequilla",                  "kg", 14000, :dairy ],
  [ "Tomate verde",                 "kg",  2800, :produce ],
  [ "Chile serrano",                "kg",  6000, :produce ],
  [ "Cebolla blanca",               "kg",  2200, :produce ],
  [ "Cilantro",                     "kg",  8000, :produce ],
  [ "Comino molido",                "kg", 32000, :spices ],
  [ "Canela en polvo",              "kg", 45000, :spices ],
  [ "Jamaica seca",                 "kg", 11000, :pantry ],
  [ "Hoja de maíz",                 "piece",  80, :other ]
]
elena_ingredients.each do |name, unit, cents, cat|
  cocina_elena.ingredients.create!(name: name, unit: unit, unit_cost_cents: cents, category: cat)
end

elena_recipes = [
  [ "Tamal verde",             2500, :mains,    1, "piece",   "tamal_verde" ],
  [ "Tamal rojo",              2500, :mains,    1, "piece",   "tamal_rojo" ],
  [ "Pozole rojo",            12000, :mains,    1, "serving", "pozole_rojo" ],
  [ "Enchiladas suizas",      14000, :mains,    1, "serving", "enchiladas_suizas" ],
  [ "Pastel de tres leches",  45000, :desserts, 1, "piece",   "pastel_tres_leches" ],
  [ "Flan napolitano",        30000, :desserts, 1, "piece",   "flan_napolitano" ],
  [ "Agua de jamaica",         4500, :drinks,   1, "l",       "agua_jamaica" ],
  [ "Champurrado",             5000, :drinks,   1, "l",       "champurrado" ]
]
puts "  …creating recipes + attaching photos"
elena_recipe_list = elena_recipes.map do |name, cents, cat, qty, unit, photo_key|
  recipe = cocina_elena.recipes.create!(
    name: name,
    sale_price_cents: cents,
    is_saleable: true,
    yield_quantity: qty,
    yield_unit: unit,
    category: cat,
    is_published: true,
    target_margin_percent: 60
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
  placed:        [],
  confirmed:     %i[confirm],
  in_production: %i[confirm start_production],
  ready:         %i[confirm start_production mark_ready],
  delivered:     %i[confirm start_production mark_ready deliver],
  paid:          %i[confirm start_production mark_ready deliver mark_paid]
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

  state_transitions[state_transitions.keys.sample].each { |e| order.send("#{e}!") }
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
    onboarding_completed: true
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

mario_ingredients = {
  "Harina de maíz nixtamalizada" => [ "kg",  2400, :pantry ],
  "Manteca de cerdo"             => [ "kg",  8500, :pantry ],
  "Sal"                          => [ "kg",  1500, :pantry ],
  "Carne al pastor marinada"     => [ "kg", 18500, :meats ],
  "Arrachera"                    => [ "kg", 26000, :meats ],
  "Pechuga de pollo"             => [ "kg", 14500, :meats ],
  "Tomate verde"                 => [ "kg",  2800, :produce ],
  "Tomate rojo"                  => [ "kg",  3200, :produce ],
  "Chile serrano"                => [ "kg",  6000, :produce ],
  "Chile de árbol"               => [ "kg",  9800, :produce ],
  "Cebolla blanca"               => [ "kg",  2200, :produce ],
  "Cilantro"                     => [ "kg",  8000, :produce ],
  "Piña"                         => [ "kg",  2800, :produce ],
  "Ajo"                          => [ "kg",  7000, :produce ],
  "Frijol bayo"                  => [ "kg",  3800, :pantry ],
  "Queso Oaxaca"                 => [ "kg", 16500, :dairy ],
  "Aceite de maíz"               => [ "l",   4200, :pantry ]
}
mario_ing = {}
mario_ingredients.each do |name, (unit, cents, cat)|
  mario_ing[name] = taqueria_mario.ingredients.create!(
    name: name, unit: unit, unit_cost_cents: cents, category: cat
  )
end

masa = taqueria_mario.recipes.create!(
  name: "Masa fresca",
  is_saleable: false,
  yield_quantity: 1800, yield_unit: "g",
  category: :bases
)
[
  [ mario_ing["Harina de maíz nixtamalizada"], 1000, "g" ],
  [ mario_ing["Manteca de cerdo"],              200, "g" ],
  [ mario_ing["Sal"],                            15, "g" ]
].each { |ing, qty, unit| masa.components.create!(componentable: ing, quantity: qty, unit: unit) }

salsa_verde = taqueria_mario.recipes.create!(
  name: "Salsa verde",
  is_saleable: false,
  yield_quantity: 500, yield_unit: "ml",
  category: :bases
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
  category: :bases
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
  category: :bases
)
[
  [ mario_ing["Frijol bayo"],      400, "g" ],
  [ mario_ing["Manteca de cerdo"], 100, "g" ],
  [ mario_ing["Cebolla blanca"],    60, "g" ]
].each { |ing, qty, unit| frijoles.components.create!(componentable: ing, quantity: qty, unit: unit) }

def build_taco(account, name:, carne:, carne_qty:, salsa:, salsa_qty:, price_cents:, masa:, mario_ing:)
  rec = account.recipes.create!(
    name: name,
    sale_price_cents: price_cents,
    is_saleable: true,
    is_published: true,
    yield_quantity: 1, yield_unit: "piece",
    category: :mains,
    target_margin_percent: 65
  )
  rec.components.create!(componentable: masa,  quantity: 30,        unit: "g")
  rec.components.create!(componentable: carne, quantity: carne_qty, unit: "g")
  rec.components.create!(componentable: salsa, quantity: salsa_qty, unit: "ml")
  rec.components.create!(componentable: mario_ing["Cebolla blanca"], quantity: 8, unit: "g")
  rec.components.create!(componentable: mario_ing["Cilantro"],       quantity: 3, unit: "g")
  rec
end

build_taco(taqueria_mario, name: "Taco al pastor",
  carne: mario_ing["Carne al pastor marinada"], carne_qty: 80,
  salsa: salsa_verde, salsa_qty: 20, price_cents: 2500,
  masa: masa, mario_ing: mario_ing)
build_taco(taqueria_mario, name: "Taco de asada",
  carne: mario_ing["Arrachera"], carne_qty: 75,
  salsa: salsa_roja,  salsa_qty: 20, price_cents: 3000,
  masa: masa, mario_ing: mario_ing)
build_taco(taqueria_mario, name: "Taco de pollo",
  carne: mario_ing["Pechuga de pollo"], carne_qty: 80,
  salsa: salsa_verde, salsa_qty: 20, price_cents: 2200,
  masa: masa, mario_ing: mario_ing)

quesadilla = taqueria_mario.recipes.create!(
  name: "Quesadilla",
  sale_price_cents: 4500, is_saleable: true, is_published: true,
  yield_quantity: 1, yield_unit: "piece",
  category: :mains, target_margin_percent: 65
)
quesadilla.components.create!(componentable: masa,                      quantity: 80, unit: "g")
quesadilla.components.create!(componentable: mario_ing["Queso Oaxaca"], quantity: 60, unit: "g")
quesadilla.components.create!(componentable: salsa_verde,               quantity: 25, unit: "ml")

sope = taqueria_mario.recipes.create!(
  name: "Sope con frijol",
  sale_price_cents: 4000, is_saleable: true, is_published: true,
  yield_quantity: 1, yield_unit: "piece",
  category: :mains, target_margin_percent: 60
)
sope.components.create!(componentable: masa,                        quantity: 100, unit: "g")
sope.components.create!(componentable: frijoles,                    quantity:  80, unit: "g")
sope.components.create!(componentable: salsa_roja,                  quantity:  25, unit: "ml")
sope.components.create!(componentable: mario_ing["Queso Oaxaca"],   quantity:  20, unit: "g")

gringa = taqueria_mario.recipes.create!(
  name: "Gringa al pastor",
  sale_price_cents: 6500, is_saleable: true, is_published: true,
  yield_quantity: 1, yield_unit: "piece",
  category: :mains, target_margin_percent: 65
)
gringa.components.create!(componentable: masa,                                  quantity: 120, unit: "g")
gringa.components.create!(componentable: mario_ing["Carne al pastor marinada"], quantity:  90, unit: "g")
gringa.components.create!(componentable: mario_ing["Queso Oaxaca"],             quantity:  60, unit: "g")
gringa.components.create!(componentable: mario_ing["Piña"],                     quantity:  30, unit: "g")

mario_saleable = taqueria_mario.recipes.saleable.to_a

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
    city:          client.city
  )
  rand(2..5).times do
    recipe = mario_saleable.sample
    order.items.create!(
      recipe:           recipe,
      quantity:         [ 1, 2, 2, 3, 4, 6 ].sample,
      unit_price_cents: recipe.sale_price_cents,
      unit_cost_cents:  (recipe.sale_price_cents * 0.35).to_i
    )
  end
  subtotal = order.items.sum { |it| it.unit_price_cents * it.quantity }
  order.update!(subtotal_cents: subtotal, total_cents: subtotal, balance_cents: subtotal)

  state_transitions[state_transitions.keys.sample].each { |e| order.send("#{e}!") }
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
end
