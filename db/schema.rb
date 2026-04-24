# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_23_214600) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.jsonb "branding", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "default_currency", default: "MXN", null: false
    t.datetime "discarded_at"
    t.boolean "iva_enabled", default: false, null: false
    t.decimal "iva_rate_percent", precision: 5, scale: 2, default: "16.0", null: false
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.jsonb "public_profile", default: {}, null: false
    t.jsonb "settings", default: {}, null: false
    t.string "slug", null: false
    t.string "time_zone", default: "America/Mexico_City", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_accounts_on_discarded_at"
    t.index ["owner_id"], name: "index_accounts_on_owner_id"
    t.index ["settings"], name: "index_accounts_on_settings", using: :gin
    t.index ["slug"], name: "index_accounts_on_slug", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "availabilities", force: :cascade do |t|
    t.boolean "available", default: true, null: false
    t.datetime "created_at", null: false
    t.date "date"
    t.integer "from_time", null: false
    t.string "note"
    t.bigint "schedule_id", null: false
    t.integer "to_time", null: false
    t.datetime "updated_at", null: false
    t.integer "wday"
    t.index ["schedule_id", "date"], name: "index_availabilities_on_schedule_id_and_date", where: "(date IS NOT NULL)"
    t.index ["schedule_id", "wday"], name: "index_availabilities_on_schedule_id_and_wday", where: "(wday IS NOT NULL)"
    t.index ["schedule_id"], name: "index_availabilities_on_schedule_id"
    t.check_constraint "from_time < to_time", name: "chk_availabilities_from_before_to"
    t.check_constraint "from_time >= 0 AND to_time <= 1440", name: "chk_availabilities_in_day"
    t.check_constraint "wday >= 0 AND wday <= 6 OR wday IS NULL", name: "chk_availabilities_wday_range"
    t.check_constraint "wday IS NOT NULL AND date IS NULL OR wday IS NULL AND date IS NOT NULL", name: "chk_availabilities_wday_xor_date"
  end

  create_table "categories", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.integer "kind", default: 0, null: false
    t.string "name", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
    t.index "account_id, kind, lower((name)::text)", name: "uniq_categories_account_kind_name", unique: true, where: "(discarded_at IS NULL)"
    t.index ["account_id", "kind", "position"], name: "index_categories_on_account_id_and_kind_and_position"
    t.index ["account_id"], name: "index_categories_on_account_id"
    t.index ["discarded_at"], name: "index_categories_on_discarded_at"
  end

  create_table "clients", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.text "allergies"
    t.date "birthday"
    t.string "city"
    t.string "colonia"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "email"
    t.string "first_name", null: false
    t.string "last_name"
    t.text "notes"
    t.string "phone"
    t.string "phone_normalized"
    t.text "references_note"
    t.string "rfc"
    t.string "street_address"
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_clients_on_account_id_and_email"
    t.index ["account_id", "phone_normalized"], name: "uniq_clients_account_phone_active", unique: true, where: "((phone_normalized IS NOT NULL) AND (discarded_at IS NULL))"
    t.index ["account_id", "rfc"], name: "index_clients_on_account_id_and_rfc", where: "(rfc IS NOT NULL)"
    t.index ["account_id"], name: "index_clients_on_account_id"
    t.index ["discarded_at"], name: "index_clients_on_discarded_at"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at"
    t.string "scope"
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "ingredients", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "MXN", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.text "notes"
    t.integer "position"
    t.datetime "price_updated_at"
    t.string "supplier_name"
    t.string "unit", null: false
    t.bigint "unit_cost_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "category_id", "position"], name: "index_ingredients_on_account_id_and_category_id_and_position"
    t.index ["account_id", "name"], name: "index_ingredients_on_account_id_and_name"
    t.index ["account_id"], name: "index_ingredients_on_account_id"
    t.index ["category_id"], name: "index_ingredients_on_category_id"
    t.index ["discarded_at"], name: "index_ingredients_on_discarded_at"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "notifications_count"
    t.jsonb "params"
    t.bigint "record_id"
    t.string "record_type"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "read_at", precision: nil
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "seen_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "order_id", null: false
    t.integer "position"
    t.decimal "quantity", precision: 10, scale: 3, default: "1.0", null: false
    t.bigint "recipe_id", null: false
    t.bigint "unit_cost_cents", default: 0, null: false
    t.bigint "unit_price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "position"], name: "index_order_items_on_order_id_and_position"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["recipe_id"], name: "index_order_items_on_recipe_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "balance_cents", default: 0, null: false
    t.string "cancel_reason_code"
    t.text "cancel_reason_note"
    t.datetime "canceled_at"
    t.string "city"
    t.bigint "client_id"
    t.string "colonia"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "delivery_address"
    t.date "delivery_date", null: false
    t.integer "delivery_end_time"
    t.integer "delivery_mode", default: 0, null: false
    t.text "delivery_notes"
    t.integer "delivery_start_time"
    t.integer "delivery_type", default: 0, null: false
    t.bigint "deposit_cents", default: 0, null: false
    t.datetime "discarded_at"
    t.datetime "en_route_started_at"
    t.datetime "geocoded_at"
    t.datetime "geocoding_failed_at"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.text "notes"
    t.datetime "paid_at"
    t.datetime "pickup_reminder_sent_at"
    t.integer "position"
    t.datetime "production_started_at"
    t.datetime "ready_at"
    t.integer "source", default: 0, null: false
    t.string "state", default: "placed", null: false
    t.bigint "subtotal_cents", default: 0, null: false
    t.bigint "tax_cents", default: 0, null: false
    t.bigint "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "delivery_date", "delivery_mode"], name: "idx_orders_account_date_delivery_mode"
    t.index ["account_id", "delivery_date"], name: "index_orders_on_account_id_and_delivery_date"
    t.index ["account_id", "state", "position"], name: "index_orders_on_account_id_and_state_and_position"
    t.index ["account_id"], name: "index_orders_on_account_id"
    t.index ["canceled_at"], name: "index_orders_on_canceled_at"
    t.index ["client_id"], name: "index_orders_on_client_id"
    t.index ["discarded_at"], name: "index_orders_on_discarded_at"
    t.index ["latitude", "longitude"], name: "index_orders_on_latitude_and_longitude"
    t.index ["ready_at"], name: "idx_orders_pickup_reminder_pending", where: "(((state)::text = 'ready'::text) AND (delivery_type = 1) AND (pickup_reminder_sent_at IS NULL))"
    t.check_constraint "delivery_end_time IS NULL OR delivery_end_time >= 0 AND delivery_end_time <= 1440", name: "chk_orders_delivery_end_time_range"
    t.check_constraint "delivery_start_time IS NULL OR delivery_end_time IS NULL OR delivery_start_time < delivery_end_time", name: "chk_orders_delivery_start_before_end"
    t.check_constraint "delivery_start_time IS NULL OR delivery_start_time >= 0 AND delivery_start_time <= 1440", name: "chk_orders_delivery_start_time_range"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "method", default: 0, null: false
    t.text "notes"
    t.bigint "order_id", null: false
    t.datetime "received_at", null: false
    t.string "reference"
    t.datetime "updated_at", null: false
    t.index ["order_id", "received_at"], name: "index_payments_on_order_id_and_received_at"
    t.index ["order_id"], name: "index_payments_on_order_id"
  end

  create_table "purchase_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "MXN", null: false
    t.bigint "ingredient_id", null: false
    t.text "notes"
    t.integer "position"
    t.bigint "purchase_id", null: false
    t.decimal "quantity", precision: 10, scale: 3, null: false
    t.string "unit", null: false
    t.bigint "unit_cost_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["ingredient_id"], name: "index_purchase_items_on_ingredient_id"
    t.index ["purchase_id", "position"], name: "index_purchase_items_on_purchase_id_and_position"
    t.index ["purchase_id"], name: "index_purchase_items_on_purchase_id"
  end

  create_table "purchases", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "MXN", null: false
    t.datetime "discarded_at"
    t.text "notes"
    t.date "purchased_on", null: false
    t.bigint "supplier_id"
    t.bigint "total_cents", default: 0, null: false
    t.bigint "total_cents_override"
    t.datetime "updated_at", null: false
    t.index ["account_id", "purchased_on"], name: "index_purchases_on_account_id_and_purchased_on"
    t.index ["account_id"], name: "index_purchases_on_account_id"
    t.index ["discarded_at"], name: "index_purchases_on_discarded_at"
    t.index ["supplier_id"], name: "index_purchases_on_supplier_id"
  end

  create_table "recipe_components", force: :cascade do |t|
    t.bigint "componentable_id", null: false
    t.string "componentable_type", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.integer "position"
    t.decimal "quantity", precision: 10, scale: 3, null: false
    t.bigint "recipe_id", null: false
    t.string "unit", null: false
    t.datetime "updated_at", null: false
    t.index ["componentable_type", "componentable_id"], name: "index_recipe_components_on_componentable"
    t.index ["recipe_id", "position"], name: "index_recipe_components_on_recipe_id_and_position"
    t.index ["recipe_id"], name: "index_recipe_components_on_recipe_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "category_id", null: false
    t.bigint "cost_cents_cached"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.boolean "is_published", default: false, null: false
    t.boolean "is_saleable", default: true, null: false
    t.string "name", null: false
    t.integer "position"
    t.bigint "sale_price_cents", default: 0, null: false
    t.string "slug", null: false
    t.integer "target_margin_percent", default: 60, null: false
    t.datetime "updated_at", null: false
    t.decimal "yield_quantity", precision: 10, scale: 3, default: "1.0", null: false
    t.string "yield_unit", default: "porcion", null: false
    t.index ["account_id", "category_id", "position"], name: "index_recipes_on_account_id_and_category_id_and_position"
    t.index ["account_id", "is_saleable"], name: "index_recipes_on_account_id_and_is_saleable"
    t.index ["account_id", "slug"], name: "index_recipes_on_account_id_and_slug", unique: true
    t.index ["account_id"], name: "index_recipes_on_account_id"
    t.index ["category_id"], name: "index_recipes_on_category_id"
    t.index ["discarded_at"], name: "index_recipes_on_discarded_at"
  end

  create_table "schedules", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.integer "lead_time_minutes", default: 0, null: false
    t.integer "order_mode", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_schedules_on_account_id", unique: true
    t.check_constraint "lead_time_minutes >= 0", name: "chk_schedules_lead_time_nonnegative"
    t.check_constraint "order_mode = ANY (ARRAY[0, 1, 2])", name: "chk_schedules_order_mode"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "cancel_at_period_end", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.integer "plan", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_subscriptions_on_account_id", unique: true
    t.index ["stripe_customer_id"], name: "index_subscriptions_on_stripe_customer_id", unique: true, where: "(stripe_customer_id IS NOT NULL)"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true, where: "(stripe_subscription_id IS NOT NULL)"
  end

  create_table "supplier_ingredients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "MXN", null: false
    t.bigint "ingredient_id", null: false
    t.boolean "is_default_cost_source", default: false, null: false
    t.date "last_bought_on"
    t.text "notes"
    t.bigint "supplier_id", null: false
    t.bigint "unit_cost_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["ingredient_id"], name: "index_supplier_ingredients_on_ingredient_id"
    t.index ["ingredient_id"], name: "uniq_default_supplier_per_ingredient", unique: true, where: "(is_default_cost_source = true)"
    t.index ["supplier_id", "ingredient_id"], name: "uniq_supplier_ingredient", unique: true
    t.index ["supplier_id"], name: "index_supplier_ingredients_on_supplier_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "city"
    t.string "colonia"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.datetime "geocoded_at"
    t.datetime "geocoding_failed_at"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "name", null: false
    t.text "notes"
    t.string "phone"
    t.string "phone_normalized"
    t.string "rfc"
    t.string "street_address"
    t.datetime "updated_at", null: false
    t.string "whatsapp"
    t.index ["account_id", "name"], name: "index_suppliers_on_account_id_and_name"
    t.index ["account_id", "phone_normalized"], name: "uniq_suppliers_account_phone_active", unique: true, where: "((phone_normalized IS NOT NULL) AND (discarded_at IS NULL))"
    t.index ["account_id", "rfc"], name: "index_suppliers_on_account_id_and_rfc", where: "(rfc IS NOT NULL)"
    t.index ["account_id"], name: "index_suppliers_on_account_id"
    t.index ["discarded_at"], name: "index_suppliers_on_discarded_at"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id"
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "email_address", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "password_digest", null: false
    t.string "phone"
    t.string "phone_normalized"
    t.datetime "terms_accepted_at"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["admin"], name: "index_users_on_admin", where: "(admin = true)"
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "accounts", "users", column: "owner_id"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "availabilities", "schedules"
  add_foreign_key "categories", "accounts"
  add_foreign_key "clients", "accounts"
  add_foreign_key "ingredients", "accounts"
  add_foreign_key "ingredients", "categories"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "recipes"
  add_foreign_key "orders", "accounts"
  add_foreign_key "orders", "clients"
  add_foreign_key "payments", "orders"
  add_foreign_key "purchase_items", "ingredients", on_delete: :cascade
  add_foreign_key "purchase_items", "purchases", on_delete: :cascade
  add_foreign_key "purchases", "accounts"
  add_foreign_key "purchases", "suppliers", on_delete: :nullify
  add_foreign_key "recipe_components", "recipes"
  add_foreign_key "recipes", "accounts"
  add_foreign_key "recipes", "categories"
  add_foreign_key "schedules", "accounts"
  add_foreign_key "sessions", "users"
  add_foreign_key "subscriptions", "accounts"
  add_foreign_key "supplier_ingredients", "ingredients", on_delete: :cascade
  add_foreign_key "supplier_ingredients", "suppliers", on_delete: :cascade
  add_foreign_key "suppliers", "accounts"
  add_foreign_key "users", "accounts"
end
