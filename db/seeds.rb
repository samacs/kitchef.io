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

puts "==> clearing existing demo data"
demo_emails = %w[elena@lvh.me mario@lvh.me]
demo_user_ids    = User.where(email_address: demo_emails).pluck(:id)
demo_account_ids = Account.where(owner_id: demo_user_ids).pluck(:id)

# Break the circular FK between users.account_id and accounts.owner_id
# before destroying either side.
User.where(account_id: demo_account_ids).update_all(account_id: nil)
Account.where(id: demo_account_ids).destroy_all
User.where(id: demo_user_ids).destroy_all

# ---------------------------------------------------------------------------
# Cocina de Elena — simple mode
# ---------------------------------------------------------------------------
puts "==> Cocina de Elena (simple mode)"

elena = User.create!(
  email_address: "elena@lvh.me",
  password:      "kitchef2026",
  first_name:    "Elena",
  last_name:     "Ramírez",
  phone:         "5512345678"
)

cocina_elena = Account.create!(
  owner: elena,
  name:  "Cocina de Elena",
  time_zone: "America/Mexico_City",
  settings: { use_composable_recipes: false, onboarding_completed: false }
)
elena.update!(account: cocina_elena)

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
  [ "Tamal verde",             2500, :mains,    1, "piece" ],
  [ "Tamal rojo",              2500, :mains,    1, "piece" ],
  [ "Pozole rojo",            12000, :mains,    1, "serving" ],
  [ "Enchiladas suizas",      14000, :mains,    1, "serving" ],
  [ "Pastel de tres leches",  45000, :desserts, 1, "piece" ],
  [ "Flan napolitano",        30000, :desserts, 1, "piece" ],
  [ "Agua de jamaica",         4500, :drinks,   1, "l" ],
  [ "Champurrado",             5000, :drinks,   1, "l" ]
]
elena_recipe_list = elena_recipes.map do |name, cents, cat, qty, unit|
  cocina_elena.recipes.create!(
    name: name,
    sale_price_cents: cents,
    is_saleable: true,
    yield_quantity: qty,
    yield_unit: unit,
    category: cat,
    is_published: true,
    target_margin_percent: 60
  )
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
  email_address: "mario@lvh.me",
  password:      "kitchef2026",
  first_name:    "Mario",
  last_name:     "Hernández",
  phone:         "5587654321"
)

taqueria_mario = Account.create!(
  owner: mario,
  name:  "Taquería Don Mario",
  time_zone: "America/Mexico_City",
  settings: {
    use_composable_recipes: true,
    composable_recipes_unlocked_at: 2.weeks.ago,
    onboarding_completed: true
  }
)
mario.update!(account: taqueria_mario)

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
