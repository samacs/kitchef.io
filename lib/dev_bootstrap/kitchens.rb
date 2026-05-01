module DevBootstrap
  # Eight realistic Hermosillo kitchens — each with a distinct culinary
  # identity, real street addresses for geocoding, curated Unsplash IDs
  # for recipe photos, and calibrated pricing at Hermosillo 2026 levels.
  #
  # The first two (Doña Lupita, El Fogón) are the "advanced-mode" kitchens
  # with fully decomposed recipes and 30+ days of order history.
  #
  # Kitchen 1–2: advanced mode, 30-day history, full decomposition
  # Kitchen 3–4: simple mode, recent history (1–2 weeks)
  # Kitchen 5–8: simple mode, fresh/minimal data (getting-started feel)
  module Kitchens
    HERMOSILLO_TZ = "America/Hermosillo".freeze
    PASSWORD      = "kitchef2026".freeze

    ALL = [
      # ── 1. Doña Lupita — comida casera sonorense (ADVANCED, 30d) ───
      {
        key: :dona_lupita,
        owner: { first: "Guadalupe", last: "Morales Durazo", email: "lupita@kitchef.mx" },
        account: {
          name: "Cocina Doña Lupita",
          street_address: "Boulevard Solidaridad 450",
          colonia: "Villa de Seris",
          city: "Hermosillo",
          tagline: "Comida casera sonorense · Villa de Seris",
          description: "Treinta años cocinando lo que mi abuela me enseñó. Caldo de queso, machaca con huevo, tamales de elote y burritos de todos los guisados. Entrega los jueves y sábados.",
          lat: 29.0672, lon: -110.9607,
          palette: "terracota", secondary: "bosque",
          delivery_zones: "Villa de Seris, Centro, Centenario, Pitic, Modelo",
          fulfillment: "pickup,delivery",
          plan: :pro,
          packaging_cents: 800,
          show_pickup_address: true,
          accepts_cash: true, accepts_transfer: true, accepts_card: false,
          transfer_holder: "Guadalupe Morales Durazo", transfer_bank: "Banamex",
          transfer_clabe: "002760700284736415",
          accepts_tips: true, tip_presets: [ 10, 15, 20 ]
        },
        mode: :advanced,
        history_days: 35,
        cover_photo_id: "photo-1565299624946-b28f40a0ae38",
        logo_photo_id:  "photo-1604908176997-125f25cc6f3d",
        ingredients: [
          { name: "Harina de trigo",     cat: "Abarrotes",   unit: "kg",    cost: 28 },
          { name: "Manteca de cerdo",    cat: "Abarrotes",   unit: "kg",    cost: 95 },
          { name: "Chile colorado seco", cat: "Especias",    unit: "kg",    cost: 180 },
          { name: "Chile verde",         cat: "Frutas y verduras", unit: "kg", cost: 45 },
          { name: "Tomate bola",         cat: "Frutas y verduras", unit: "kg", cost: 32 },
          { name: "Cebolla blanca",      cat: "Frutas y verduras", unit: "kg", cost: 22 },
          { name: "Papa blanca",         cat: "Frutas y verduras", unit: "kg", cost: 28 },
          { name: "Queso chihuahua",     cat: "Lácteos",     unit: "kg",    cost: 180 },
          { name: "Queso fresco",        cat: "Lácteos",     unit: "kg",    cost: 120 },
          { name: "Leche entera",        cat: "Lácteos",     unit: "l",     cost: 26 },
          { name: "Machaca de res",      cat: "Carnes",      unit: "kg",    cost: 320 },
          { name: "Bistec de res",       cat: "Carnes",      unit: "kg",    cost: 220 },
          { name: "Pollo entero",        cat: "Carnes",      unit: "kg",    cost: 85 },
          { name: "Chorizo regional",    cat: "Carnes",      unit: "kg",    cost: 140 },
          { name: "Elote tierno",        cat: "Frutas y verduras", unit: "piece", cost: 12 },
          { name: "Aceite vegetal",      cat: "Abarrotes",   unit: "l",     cost: 42 },
          { name: "Arroz",               cat: "Abarrotes",   unit: "kg",    cost: 24 },
          { name: "Frijol pinto",        cat: "Abarrotes",   unit: "kg",    cost: 38 },
          { name: "Ajo",                 cat: "Especias",    unit: "kg",    cost: 110 },
          { name: "Comino",              cat: "Especias",    unit: "kg",    cost: 280 }
        ],
        suppliers: [
          { name: "Mercado Municipal",      colonia: "Centro" },
          { name: "Carnicería Don Beto",    colonia: "Villa de Seris" },
          { name: "Abarrotes La Esperanza", colonia: "Centenario" }
        ],
        base_recipes: [
          { name: "Salsa roja sonorense", yield_qty: 1, yield_unit: "l", ingredients: [ { name: "Chile colorado seco", qty: 0.15 }, { name: "Tomate bola", qty: 0.5 }, { name: "Ajo", qty: 0.02 }, { name: "Comino", qty: 0.005 } ] },
          { name: "Frijoles refritos",    yield_qty: 1, yield_unit: "kg", ingredients: [ { name: "Frijol pinto", qty: 0.5 }, { name: "Manteca de cerdo", qty: 0.05 }, { name: "Cebolla blanca", qty: 0.1 } ] },
          { name: "Guisado de machaca",   yield_qty: 1, yield_unit: "kg", ingredients: [ { name: "Machaca de res", qty: 0.4 }, { name: "Chile verde", qty: 0.2 }, { name: "Tomate bola", qty: 0.2 }, { name: "Cebolla blanca", qty: 0.1 } ] },
          # Byproduct demo: cooking caldo also yields pollo deshebrado
          { name: "Pollo deshebrado",     yield_qty: 0.5, yield_unit: "kg", ingredients: [] },
          { name: "Caldo de pollo base",  yield_qty: 2,   yield_unit: "l",
            ingredients: [ { name: "Pollo entero", qty: 1 }, { name: "Cebolla blanca", qty: 0.15 }, { name: "Ajo", qty: 0.01 } ],
            byproducts: [ "Pollo deshebrado" ] }
        ],
        recipes: [
          { name: "Burrito de machaca",     price: 75,  photo_id: "photo-1626700051175-6818013e1d4f", cat: "Platos fuertes", base: "Guisado de machaca",
            # Removable ingredient demo: customer can request "sin cebolla"
            components: [
              { name: "Cebolla blanca", qty: 0.05, unit: "kg", removable: true }
            ] },
          { name: "Burrito de chile colorado", price: 70, photo_id: "photo-1584208632869-05fa2b2a5934", cat: "Platos fuertes" },
          { name: "Caldo de queso",         price: 95,  photo_id: "photo-1559847844-5315695dadae", cat: "Platos fuertes",
            components: [
              { name: "Queso chihuahua", qty: 0.15, unit: "kg" },
              { name: "Chile verde",     qty: 0.1,  unit: "kg", removable: true },
              { name: "Papa blanca",     qty: 0.2,  unit: "kg" },
              { name: "Leche entera",    qty: 0.3,  unit: "l" },
              { name: "Cebolla blanca",  qty: 0.05, unit: "kg", removable: true }
            ],
            # Check option group demo: multiple extras with inventory tracking
            option_groups: [
              { label: "Extras", sub: "Agrega lo que quieras", kind: :check, required: false,
                options: [
                  { label: "Extra queso",  delta: 15, ingredient: "Queso chihuahua", qty: 0.05, unit: "kg" },
                  { label: "Extra papa",   delta: 10, ingredient: "Papa blanca",     qty: 0.1,  unit: "kg" },
                  { label: "Con chorizo",  delta: 20, ingredient: "Chorizo regional", qty: 0.08, unit: "kg" }
                ] }
            ] },
          { name: "Tamales de elote",       price: 30,  photo_id: "photo-1625938144755-652e08e359b7", cat: "Entradas" },
          { name: "Machaca con huevo",      price: 85,  photo_id: "photo-1565299585323-38d6b0865b47", cat: "Platos fuertes", base: "Guisado de machaca" },
          { name: "Agua de cebada",         price: 25,  photo_id: "photo-1544145945-f90425340c7e", cat: "Bebidas" },
          # Byproduct consumer: uses the pollo deshebrado from caldo de pollo
          { name: "Frijoles charros",       price: 55,  photo_id: "photo-1574894709920-11b28e7367e3", cat: "Entradas",
            components: [
              { name: "Frijol pinto", qty: 0.3, unit: "kg" },
              { base: "Pollo deshebrado", qty: 0.1, unit: "kg" }
            ] },
          { name: "Orden de 3 burritos",    price: 210, photo_id: "photo-1626700051175-6818013e1d4f", cat: "Platos fuertes",
            yield_qty: 3, yield_unit: "piece",
            option_groups: [
              { label: "Guisado", sub: "Elige el guisado para tus 3 burritos", kind: :radio, required: true,
                options: [
                  { label: "Machaca",    default: true, delta: 0,  ingredient: "Machaca de res",  qty: 0.12, unit: "kg" },
                  { label: "Chile rojo", default: false, delta: 0, base: "Salsa roja sonorense",  qty: 0.10, unit: "l" },
                  { label: "Frijol",     default: false, delta: -15, base: "Frijoles refritos",   qty: 0.15, unit: "kg" }
                ] }
            ] },
          # Made-to-order demo: assembled fresh per order, no batch needed
          { name: "Quesadilla al momento", price: 45, photo_id: "photo-1565299585323-38d6b0865b47", cat: "Platos fuertes",
            made_to_order: true,
            components: [
              { name: "Harina de trigo",  qty: 0.08, unit: "kg" },
              { name: "Queso chihuahua",  qty: 0.1,  unit: "kg" },
              { name: "Manteca de cerdo", qty: 0.02, unit: "kg" }
            ],
            option_groups: [
              { label: "Relleno", sub: "Elige qué le ponemos", kind: :check, required: false,
                options: [
                  { label: "Machaca",  delta: 25, ingredient: "Machaca de res",  qty: 0.06, unit: "kg" },
                  { label: "Chorizo", delta: 15, ingredient: "Chorizo regional", qty: 0.05, unit: "kg" },
                  { label: "Rajas",   delta: 10, ingredient: "Chile verde",      qty: 0.04, unit: "kg" }
                ] }
            ] }
        ],
        fixed_costs: [
          { category: "Renta",           amount: 9000,  recurrence: :monthly },
          { category: "Gas y servicios", amount: 2500,  recurrence: :monthly },
          { category: "Empaque",         amount: 1500,  recurrence: :monthly }
        ]
      },

      # ── 2. El Fogón de Nacho — carne asada y cortes (ADVANCED, 30d) ──
      {
        key: :el_fogon,
        owner: { first: "Ignacio", last: "Valenzuela Robles", email: "nacho@kitchef.mx" },
        account: {
          name: "El Fogón de Nacho",
          street_address: "Calle Yáñez 78",
          colonia: "Centro",
          city: "Hermosillo",
          tagline: "Carne asada, cortes y guarniciones · Centro",
          description: "Cortes sonorenses al carbón con tortillas de harina hechas a mano. Cabrería, arrachera, costillas, y los frijoles maneados que no pueden faltar. Pedidos para eventos y comidas familiares.",
          lat: 29.0729, lon: -110.9559,
          palette: "tinto", secondary: "terracota",
          delivery_zones: "Centro, Centenario, Pitic, Modelo, Las Quintas",
          fulfillment: "pickup,delivery",
          plan: :pro,
          packaging_cents: 1200,
          show_pickup_address: true,
          accepts_cash: true, accepts_transfer: true, accepts_card: true,
          transfer_holder: "Ignacio Valenzuela Robles", transfer_bank: "BBVA Bancomer",
          transfer_clabe: "012760001789456321",
          card_instructions: "Acepto tarjeta por link de Mercado Pago — te lo mando por WhatsApp al confirmar.",
          accepts_tips: true, tip_presets: [ 10, 15, 20 ]
        },
        mode: :advanced,
        history_days: 30,
        cover_photo_id: "photo-1558030006-450675393462",
        logo_photo_id:  "photo-1552566626-52f8b828add9",
        ingredients: [
          { name: "Arrachera",           cat: "Carnes", unit: "kg", cost: 280 },
          { name: "Cabrería",            cat: "Carnes", unit: "kg", cost: 250 },
          { name: "Costilla de res",     cat: "Carnes", unit: "kg", cost: 190 },
          { name: "Pollo marinado",      cat: "Carnes", unit: "kg", cost: 95 },
          { name: "Chorizo sonorense",   cat: "Carnes", unit: "kg", cost: 150 },
          { name: "Harina de trigo",     cat: "Abarrotes", unit: "kg", cost: 28 },
          { name: "Manteca",             cat: "Abarrotes", unit: "kg", cost: 90 },
          { name: "Cebolla cambray",     cat: "Frutas y verduras", unit: "piece", cost: 15 },
          { name: "Chile güero",         cat: "Frutas y verduras", unit: "kg", cost: 55 },
          { name: "Limón",               cat: "Frutas y verduras", unit: "kg", cost: 30 },
          { name: "Frijol pinto",        cat: "Abarrotes", unit: "kg", cost: 38 },
          { name: "Queso chihuahua",     cat: "Lácteos",   unit: "kg", cost: 180 },
          { name: "Guacamole (hecho)",   cat: "Otros",     unit: "kg", cost: 150 },
          { name: "Carbón mesquite",     cat: "Otros",     unit: "kg", cost: 22 }
        ],
        suppliers: [
          { name: "Carnes Selectas El Toro", colonia: "Centro" },
          { name: "Bodega Aurrerá Centro",   colonia: "Centro" },
          { name: "Mercado Municipal",       colonia: "Centro" }
        ],
        base_recipes: [
          { name: "Tortillas de harina", yield_qty: 12, yield_unit: "piece", ingredients: [ { name: "Harina de trigo", qty: 0.5 }, { name: "Manteca", qty: 0.08 } ] },
          { name: "Frijoles maneados",   yield_qty: 1,  yield_unit: "kg",  ingredients: [ { name: "Frijol pinto", qty: 0.5 }, { name: "Queso chihuahua", qty: 0.15 }, { name: "Manteca", qty: 0.05 } ] }
        ],
        # El Fogón uses block oversell policy — agotado disables add-to-cart
        oversell_policy: "block",
        recipes: [
          { name: "Arrachera al carbón",   price: 280, photo_id: "photo-1558030006-450675393462", cat: "Platos fuertes",
            # Swatch option group demo: visual salsa picker with colors
            option_groups: [
              { label: "Salsa", sub: "Elige tu salsa", kind: :swatch, required: false,
                options: [
                  { label: "Verde",  default: true,  delta: 0, color: "#2D6A4F" },
                  { label: "Roja",   default: false, delta: 0, color: "#9B2B1E" },
                  { label: "Negra",  default: false, delta: 0, color: "#2F3A35" },
                  { label: "Sin salsa", default: false, delta: 0 }
                ] }
            ] },
          { name: "Cabrería 500g",         price: 250, photo_id: "photo-1544025162-d76694265947", cat: "Platos fuertes" },
          { name: "Costillar BBQ",         price: 320, photo_id: "photo-1529193591184-b1d58069ecdd", cat: "Platos fuertes" },
          { name: "Pollo al carbón",       price: 160, photo_id: "photo-1598515214211-89d3c73ae83b", cat: "Platos fuertes" },
          { name: "Chorizo asado",         price: 120, photo_id: "photo-1555939594-58d7cb561ad1", cat: "Entradas" },
          { name: "Frijoles maneados",     price: 65,  photo_id: "photo-1574894709920-11b28e7367e3", cat: "Entradas", base: "Frijoles maneados" },
          { name: "Agua de horchata",      price: 30,  photo_id: "photo-1590523741831-ab7e8b8f9c7f", cat: "Bebidas" },
          { name: "Plato de carne al carbón", price: 280, photo_id: "photo-1558030006-450675393462", cat: "Platos fuertes",
            option_groups: [
              { label: "Corte", sub: "Elige tu corte de carne", kind: :radio, required: true,
                options: [
                  { label: "Arrachera",  default: true,  delta: 0,   ingredient: "Arrachera",       qty: 0.25, unit: "kg" },
                  { label: "Cabrería",   default: false, delta: -30, ingredient: "Cabrería",        qty: 0.25, unit: "kg" },
                  { label: "Costilla",   default: false, delta: 40,  ingredient: "Costilla de res", qty: 0.30, unit: "kg" },
                  { label: "Pollo",      default: false, delta: -80, ingredient: "Pollo marinado",  qty: 0.25, unit: "kg" }
                ] },
              # Textarea option group demo: free-text cooking instructions
              { label: "Instrucciones", sub: "¿Alguna indicación especial?", kind: :textarea, required: false,
                max_length: 200 }
            ] },
          # Made-to-order + per-unit selection: each taco gets its own filling
          { name: "Tacos al carbón (3 piezas)", price: 120, photo_id: "photo-1555939594-58d7cb561ad1", cat: "Platos fuertes",
            made_to_order: true,
            yield_qty: 3, yield_unit: "piece",
            components: [
              { name: "Harina de trigo", qty: 0.15, unit: "kg" },
              { name: "Limón",           qty: 0.05, unit: "kg" },
              { name: "Cebolla cambray", qty: 3,    unit: "piece" }
            ],
            option_groups: [
              { label: "Relleno por taco", sub: "Elige la carne para cada taco", kind: :radio, required: true,
                selection_mode: :per_unit, unit_count: 3,
                options: [
                  { label: "Arrachera",  default: true,  delta: 0,   ingredient: "Arrachera",       qty: 0.08, unit: "kg" },
                  { label: "Pollo",      default: false, delta: -20, ingredient: "Pollo marinado",  qty: 0.08, unit: "kg" },
                  { label: "Chorizo",    default: false, delta: -10, ingredient: "Chorizo sonorense", qty: 0.06, unit: "kg" }
                ] }
            ] }
        ],
        fixed_costs: [
          { category: "Renta",            amount: 12000, recurrence: :monthly },
          { category: "Gas y servicios",  amount: 4500,  recurrence: :monthly },
          { category: "Plataformas",      amount: 600,   recurrence: :weekly },
          { category: "Empaque",          amount: 2000,  recurrence: :monthly }
        ]
      },

      # ── 3. Tamales Doña Carmen — tamales sonorenses (SIMPLE, 2 weeks) ──
      {
        key: :dona_carmen,
        owner: { first: "Carmen", last: "Félix Ochoa", email: "carmen@kitchef.mx" },
        account: {
          name: "Tamales Doña Carmen",
          street_address: "Calle Nayarit 201",
          colonia: "Olivares",
          city: "Hermosillo",
          tagline: "Tamales de elote, chile colorado y dulce · Olivares",
          description: "Tamales sonorenses para cualquier ocasión. Los encargamos con un día de anticipación. Hoja de maíz, sin conservadores.",
          lat: 29.0835, lon: -110.9712,
          palette: "mostaza", secondary: "terracota",
          delivery_zones: "Olivares, Las Quintas, Sahuaro",
          fulfillment: "pickup,delivery",
          plan: :free,
          packaging_cents: 500,
          show_pickup_address: true,
          accepts_cash: true, accepts_transfer: true, accepts_card: false,
          transfer_holder: "Carmen Félix Ochoa", transfer_bank: "Banorte",
          transfer_clabe: "072760004512367890",
          accepts_tips: true, tip_presets: [ 10, 15, 20 ]
        },
        mode: :simple,
        history_days: 14,
        cover_photo_id: "photo-1599974579688-8dbdd335c77f",
        logo_photo_id:  "photo-1625938144755-652e08e359b7",
        ingredients: [],
        suppliers: [],
        base_recipes: [],
        recipes: [
          { name: "Tamal de elote",            price: 30, photo_id: "photo-1625938144755-652e08e359b7", cat: "Platos fuertes" },
          { name: "Tamal de chile colorado",   price: 35, photo_id: "photo-1599974579688-8dbdd335c77f", cat: "Platos fuertes" },
          { name: "Tamal de dulce",            price: 28, photo_id: "photo-1612392166886-ee8475b03af2", cat: "Postres" },
          { name: "Docena surtida",            price: 350, photo_id: "photo-1599974579688-8dbdd335c77f", cat: "Platos fuertes" }
        ],
        fixed_costs: [
          { category: "Gas y servicios", amount: 1800, recurrence: :monthly }
        ]
      },

      # ── 4. Postres de Mariana — pasteles y postres (SIMPLE, 2 weeks) ──
      {
        key: :postres_mariana,
        owner: { first: "Mariana", last: "Córdova Grijalva", email: "mariana@kitchef.mx" },
        account: {
          name: "Postres de Mariana",
          street_address: "Boulevard Morelos 312",
          colonia: "Bachoco",
          city: "Hermosillo",
          tagline: "Pasteles, gelatinas y postres por encargo · Bachoco",
          description: "Postres para fiestas, cumpleaños y reuniones familiares. Todo se prepara fresco un día antes de la entrega. Sabores clásicos y de temporada.",
          lat: 29.0789, lon: -110.9423,
          palette: "rosa", secondary: "durazno",
          delivery_zones: "Bachoco, Las Granjas, Colinas del Yaqui",
          fulfillment: "delivery",
          plan: :free,
          packaging_cents: 3500,
          show_pickup_address: false,
          accepts_cash: true, accepts_transfer: true, accepts_card: false,
          transfer_holder: "Mariana Córdova Grijalva", transfer_bank: "HSBC",
          transfer_clabe: "021760008934561234",
          accepts_tips: true, tip_presets: [ 10, 15, 20 ]
        },
        mode: :simple,
        history_days: 14,
        cover_photo_id: "photo-1565299624946-b28f40a0ae38",
        logo_photo_id:  "photo-1604908176997-125f25cc6f3d",
        ingredients: [],
        suppliers: [],
        base_recipes: [],
        recipes: [
          { name: "Pastel tres leches",     price: 450, photo_id: "photo-1565299624946-b28f40a0ae38", cat: "Postres", lead_time: 24 },
          { name: "Pastel de chocolate",    price: 480, photo_id: "photo-1578985545062-69928b1d9587", cat: "Postres", lead_time: 24 },
          { name: "Gelatina mosaico",       price: 180, photo_id: "photo-1488477181946-6428a0291777", cat: "Postres", lead_time: 12 },
          { name: "Flan napolitano",        price: 220, photo_id: "photo-1528975604071-b4dc52a2d18c", cat: "Postres", lead_time: 12 },
          { name: "Pay de queso",           price: 350, photo_id: "photo-1524351199678-941a58a3df50", cat: "Postres", lead_time: 24 }
        ],
        fixed_costs: [
          { category: "Renta",           amount: 6000, recurrence: :monthly },
          { category: "Gas y servicios", amount: 1200, recurrence: :monthly }
        ]
      },

      # ── 5. Mariscos del Pacífico — mariscos a domicilio (SIMPLE, fresh) ──
      {
        key: :mariscos_pacifico,
        owner: { first: "Roberto", last: "Armenta Lugo", email: "roberto@kitchef.mx" },
        account: {
          name: "Mariscos del Pacífico",
          street_address: "Avenida Cultura Norte 88",
          colonia: "El Sahuaro",
          city: "Hermosillo",
          tagline: "Aguachile, ceviche y cócteles de camarón · El Sahuaro",
          description: "Mariscos frescos traídos de Guaymas y Bahía de Kino. Preparamos todo el mismo día. Entregamos en menos de una hora en zona centro.",
          lat: 29.0996, lon: -110.9672,
          palette: "cobalto", secondary: "pizarra",
          delivery_zones: "El Sahuaro, Las Quintas, Centro",
          fulfillment: "delivery",
          plan: :free,
          packaging_cents: 1000,
          show_pickup_address: false,
          accepts_cash: true, accepts_transfer: false, accepts_card: false,
          accepts_tips: false, tip_presets: [ 10, 15, 20 ]
        },
        mode: :simple,
        history_days: 5,
        cover_photo_id: "photo-1565299585323-38d6b0865b47",
        logo_photo_id:  "photo-1552566626-52f8b828add9",
        ingredients: [],
        suppliers: [],
        base_recipes: [],
        recipes: [
          { name: "Aguachile negro",        price: 160, photo_id: "photo-1565299585323-38d6b0865b47", cat: "Platos fuertes" },
          { name: "Ceviche de camarón",     price: 130, photo_id: "photo-1559847844-5315695dadae", cat: "Platos fuertes" },
          { name: "Cóctel de camarón",      price: 120, photo_id: "photo-1574894709920-11b28e7367e3", cat: "Entradas" },
          { name: "Tostada de marlín",      price: 85,  photo_id: "photo-1584208632869-05fa2b2a5934", cat: "Entradas" }
        ],
        fixed_costs: []
      },

      # ── 6. Lonches La Rueda — lonches y hot dogs sonorenses (SIMPLE) ──
      {
        key: :lonches_rueda,
        owner: { first: "Francisco", last: "Duarte Siqueiros", email: "pancho@kitchef.mx" },
        account: {
          name: "Lonches La Rueda",
          street_address: "Boulevard Luis Encinas 155",
          colonia: "San Benito",
          city: "Hermosillo",
          tagline: "Lonches, dogos y hamburguesas · San Benito",
          description: "Los dogos y lonches de siempre, con los ingredientes de toda la vida. Tocino, frijoles, guacamole y salsa de chile de árbol. De miércoles a domingo.",
          lat: 29.0952, lon: -110.9498,
          palette: "cacao", secondary: "mostaza",
          delivery_zones: "San Benito, Centro",
          fulfillment: "pickup",
          plan: :free,
          packaging_cents: 300,
          show_pickup_address: true,
          accepts_cash: true, accepts_transfer: false, accepts_card: false,
          accepts_tips: false, tip_presets: [ 10, 15, 20 ]
        },
        mode: :simple,
        history_days: 3,
        cover_photo_id: "photo-1558030006-450675393462",
        logo_photo_id:  "photo-1555939594-58d7cb561ad1",
        ingredients: [],
        suppliers: [],
        base_recipes: [],
        recipes: [
          { name: "Dogo sonorense",     price: 65,  photo_id: "photo-1558030006-450675393462", cat: "Platos fuertes" },
          { name: "Lonche de pierna",   price: 55,  photo_id: "photo-1626700051175-6818013e1d4f", cat: "Platos fuertes" },
          { name: "Hamburguesa clásica", price: 85, photo_id: "photo-1555939594-58d7cb561ad1", cat: "Platos fuertes" }
        ],
        fixed_costs: []
      },

      # ── 7. Comida Corrida Sonora — menú del día (SIMPLE) ──
      {
        key: :comida_corrida,
        owner: { first: "Patricia", last: "Navarro Encinas", email: "paty@kitchef.mx" },
        account: {
          name: "Comida Corrida Sonora",
          street_address: "Calle Plutarco Elías Calles 40",
          colonia: "Pitic",
          city: "Hermosillo",
          tagline: "Menú del día con sopa, guisado y postre · Pitic",
          description: "Comida casera de lunes a viernes. Sopa del día, guisado con arroz y frijoles, agua fresca y postre. Entrega de 12 a 3 pm.",
          lat: 29.0685, lon: -110.9553,
          palette: "bosque", secondary: "terracota",
          delivery_zones: "Pitic, Centro, Centenario",
          fulfillment: "pickup,delivery",
          plan: :free,
          packaging_cents: 500,
          show_pickup_address: true,
          accepts_cash: true, accepts_transfer: true, accepts_card: false,
          transfer_holder: "Patricia Navarro Encinas", transfer_bank: "Banco Azteca",
          transfer_clabe: "127760009876543210",
          accepts_tips: true, tip_presets: [ 10, 15, 20 ]
        },
        mode: :simple,
        history_days: 7,
        cover_photo_id: "photo-1565299624946-b28f40a0ae38",
        logo_photo_id:  "photo-1604908176997-125f25cc6f3d",
        ingredients: [],
        suppliers: [],
        base_recipes: [],
        recipes: [
          { name: "Comida corrida completa",  price: 95,  photo_id: "photo-1565299624946-b28f40a0ae38", cat: "Platos fuertes" },
          { name: "Guisado con tortillas",    price: 75,  photo_id: "photo-1574894709920-11b28e7367e3", cat: "Platos fuertes" },
          { name: "Sopa del día (litro)",     price: 50,  photo_id: "photo-1559847844-5315695dadae", cat: "Entradas" },
          { name: "Agua fresca del día",      price: 20,  photo_id: "photo-1544145945-f90425340c7e", cat: "Bebidas" }
        ],
        fixed_costs: [
          { category: "Renta",           amount: 5000, recurrence: :monthly },
          { category: "Gas y servicios", amount: 2200, recurrence: :monthly }
        ]
      },

      # ── 8. Capirotada y Más — postres regionales (SIMPLE) ──
      {
        key: :capirotada,
        owner: { first: "Sofía", last: "Grijalva Tapia", email: "sofia@kitchef.mx" },
        account: {
          name: "Capirotada y Más",
          street_address: "Avenida Serdán 567",
          colonia: "Centenario",
          city: "Hermosillo",
          tagline: "Capirotada, coyotas y dulces sonorenses · Centenario",
          description: "Dulces típicos de Sonora hechos con recetas familiares. Coyotas de piloncillo, jamoncillo de leche, capirotada de cuaresma y empanadas de calabaza.",
          lat: 29.0748, lon: -110.9631,
          palette: "durazno", secondary: "rosa",
          delivery_zones: "Centenario, Centro, Villa de Seris",
          fulfillment: "pickup",
          plan: :free,
          packaging_cents: 400,
          show_pickup_address: true,
          accepts_cash: true, accepts_transfer: true, accepts_card: false,
          transfer_holder: "Sofía Grijalva Tapia", transfer_bank: "Banorte",
          transfer_clabe: "072760001234567890",
          accepts_tips: true, tip_presets: [ 10, 15, 20 ]
        },
        mode: :simple,
        history_days: 3,
        cover_photo_id: "photo-1612392166886-ee8475b03af2",
        logo_photo_id:  "photo-1578985545062-69928b1d9587",
        ingredients: [],
        suppliers: [],
        base_recipes: [],
        recipes: [
          { name: "Capirotada de piloncillo", price: 120, photo_id: "photo-1612392166886-ee8475b03af2", cat: "Postres" },
          { name: "Coyotas de piloncillo",    price: 15,  photo_id: "photo-1524351199678-941a58a3df50", cat: "Postres" },
          { name: "Empanadas de calabaza",     price: 20,  photo_id: "photo-1528975604071-b4dc52a2d18c", cat: "Postres" },
          { name: "Jamoncillo de leche",       price: 45,  photo_id: "photo-1488477181946-6428a0291777", cat: "Postres" }
        ],
        fixed_costs: []
      }
    ].freeze
  end
end
