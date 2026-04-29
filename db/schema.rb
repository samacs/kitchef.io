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

ActiveRecord::Schema[8.1].define(version: 2026_04_29_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "fuzzystrmatch"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"
  enable_extension "pg_trgm"
  enable_extension "vector"

  create_table "accounts", force: :cascade do |t|
    t.jsonb "branding", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "default_currency", default: "MXN", null: false
    t.boolean "demo", default: false, null: false
    t.datetime "discarded_at"
    t.datetime "geocoded_at"
    t.datetime "geocoding_failed_at"
    t.boolean "iva_enabled", default: false, null: false
    t.decimal "iva_rate_percent", precision: 5, scale: 2, default: "16.0", null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.jsonb "public_profile", default: {}, null: false
    t.jsonb "settings", default: {}, null: false
    t.string "slug", null: false
    t.string "street_address"
    t.string "time_zone", default: "America/Mexico_City", null: false
    t.datetime "updated_at", null: false
    t.index ["demo"], name: "idx_accounts_demo_true", where: "(demo = true)"
    t.index ["discarded_at"], name: "index_accounts_on_discarded_at"
    t.index ["latitude", "longitude"], name: "index_accounts_on_latitude_and_longitude"
    t.index ["owner_id"], name: "index_accounts_on_owner_id"
    t.index ["settings"], name: "index_accounts_on_settings", using: :gin
    t.index ["slug"], name: "index_accounts_on_slug", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position"
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
    t.index ["record_type", "record_id", "name", "position"], name: "idx_asa_record_position", where: "(\"position\" IS NOT NULL)"
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

  create_table "batch_consumptions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.bigint "consumable_id", null: false
    t.string "consumable_type", null: false
    t.bigint "cost_cents_at_consumption", default: 0, null: false
    t.datetime "created_at", null: false
    t.decimal "quantity_consumed", precision: 14, scale: 3, null: false
    t.string "unit", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id"], name: "index_batch_consumptions_on_batch_id"
    t.index ["consumable_type", "consumable_id"], name: "idx_batch_consumptions_consumable"
  end

  create_table "batches", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "actual_quantity", precision: 12, scale: 3, default: "0.0", null: false
    t.date "available_from", null: false
    t.date "available_until", null: false
    t.datetime "canceled_at"
    t.datetime "completed_at"
    t.date "cooked_on", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.text "notes"
    t.decimal "planned_quantity", precision: 12, scale: 3, default: "0.0", null: false
    t.bigint "recipe_id", null: false
    t.datetime "started_at"
    t.string "state", default: "planned", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "available_from", "available_until"], name: "idx_batches_account_window"
    t.index ["account_id", "cooked_on"], name: "index_batches_on_account_id_and_cooked_on"
    t.index ["account_id", "recipe_id", "cooked_on"], name: "index_batches_on_account_id_and_recipe_id_and_cooked_on"
    t.index ["account_id"], name: "index_batches_on_account_id"
    t.index ["discarded_at"], name: "index_batches_on_discarded_at"
    t.index ["recipe_id"], name: "index_batches_on_recipe_id"
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
    t.index ["email"], name: "idx_clients_email_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["first_name"], name: "idx_clients_first_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["last_name"], name: "idx_clients_last_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["phone_normalized"], name: "idx_clients_phone_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "fixed_cost_categories", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.integer "kind", default: 99, null: false
    t.string "name", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
    t.index "account_id, lower((name)::text)", name: "uniq_fixed_cost_categories_account_name", unique: true, where: "(discarded_at IS NULL)"
    t.index ["account_id", "kind", "position"], name: "idx_on_account_id_kind_position_20bc8955b1"
    t.index ["account_id"], name: "index_fixed_cost_categories_on_account_id"
    t.index ["discarded_at"], name: "index_fixed_cost_categories_on_discarded_at"
  end

  create_table "fixed_costs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "amount_cents", default: 0, null: false
    t.bigint "cost_per_pedido_cents"
    t.datetime "created_at", null: false
    t.string "currency", default: "MXN", null: false
    t.datetime "discarded_at"
    t.date "end_date"
    t.bigint "fixed_cost_category_id", null: false
    t.text "notes"
    t.integer "recurrence", default: 0, null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "start_date"], name: "index_fixed_costs_on_account_id_and_start_date"
    t.index ["account_id"], name: "index_fixed_costs_on_account_id"
    t.index ["discarded_at"], name: "index_fixed_costs_on_discarded_at"
    t.index ["fixed_cost_category_id"], name: "index_fixed_costs_on_fixed_cost_category_id"
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
    t.decimal "last_purchase_quantity", precision: 12, scale: 3
    t.datetime "low_stock_alert_at"
    t.string "name", null: false
    t.text "notes"
    t.integer "position"
    t.datetime "price_updated_at"
    t.decimal "stock_quantity", precision: 12, scale: 3, default: "0.0", null: false
    t.datetime "stock_updated_at"
    t.string "supplier_name"
    t.string "unit", null: false
    t.bigint "unit_cost_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "category_id", "position"], name: "index_ingredients_on_account_id_and_category_id_and_position"
    t.index ["account_id", "name"], name: "index_ingredients_on_account_id_and_name"
    t.index ["account_id"], name: "index_ingredients_on_account_id"
    t.index ["category_id"], name: "index_ingredients_on_category_id"
    t.index ["discarded_at"], name: "index_ingredients_on_discarded_at"
    t.index ["name"], name: "idx_ingredients_name_trgm", opclass: :gin_trgm_ops, using: :gin
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
    t.bigint "consumed_batch_id"
    t.decimal "consumed_quantity", precision: 12, scale: 3, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "options_price_delta_cents", default: 0, null: false
    t.bigint "order_id", null: false
    t.boolean "oversold", default: false, null: false
    t.integer "position"
    t.decimal "quantity", precision: 10, scale: 3, default: "1.0", null: false
    t.bigint "recipe_id", null: false
    t.jsonb "removed_components", default: []
    t.jsonb "selected_options", default: {}
    t.bigint "unit_cost_cents", default: 0, null: false
    t.bigint "unit_price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["consumed_batch_id"], name: "index_order_items_on_consumed_batch_id"
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
    t.bigint "cash_payment_amount_cents"
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
    t.bigint "discount_cents", default: 0, null: false
    t.string "discount_label"
    t.datetime "en_route_started_at"
    t.datetime "geocoded_at"
    t.datetime "geocoding_failed_at"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.text "notes"
    t.bigint "packaging_cents", default: 0, null: false
    t.datetime "paid_at"
    t.integer "payment_method"
    t.datetime "pickup_reminder_sent_at"
    t.integer "position"
    t.datetime "production_started_at"
    t.datetime "ready_at"
    t.integer "source", default: 0, null: false
    t.string "state", default: "placed", null: false
    t.bigint "subtotal_cents", default: 0, null: false
    t.bigint "tax_cents", default: 0, null: false
    t.datetime "terms_accepted_at"
    t.bigint "tip_cents", default: 0, null: false
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

  create_table "promotion_categories", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.bigint "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_promotion_categories_on_category_id"
    t.index ["promotion_id", "category_id"], name: "uniq_promotion_categories", unique: true
    t.index ["promotion_id"], name: "index_promotion_categories_on_promotion_id"
  end

  create_table "promotion_recipes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "promotion_id", null: false
    t.bigint "recipe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["promotion_id", "recipe_id"], name: "uniq_promotion_recipes", unique: true
    t.index ["promotion_id"], name: "index_promotion_recipes_on_promotion_id"
    t.index ["recipe_id"], name: "index_promotion_recipes_on_recipe_id"
  end

  create_table "promotion_redemptions", force: :cascade do |t|
    t.bigint "client_id"
    t.datetime "created_at", null: false
    t.bigint "discount_cents", default: 0, null: false
    t.string "discount_label", null: false
    t.integer "kind", default: 0, null: false
    t.bigint "order_id", null: false
    t.bigint "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_promotion_redemptions_on_client_id"
    t.index ["order_id", "kind"], name: "uniq_redemption_per_kind", unique: true
    t.index ["order_id"], name: "index_promotion_redemptions_on_order_id"
    t.index ["promotion_id", "client_id"], name: "idx_promotion_client_redemptions"
    t.index ["promotion_id"], name: "index_promotion_redemptions_on_promotion_id"
  end

  create_table "promotions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "active", default: true, null: false
    t.string "badge_color"
    t.string "badge_label"
    t.integer "bogo_buy_quantity", default: 1
    t.integer "bogo_get_quantity", default: 1
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.integer "discount_type", default: 0, null: false
    t.integer "discount_value", null: false
    t.datetime "ends_at"
    t.integer "kind", default: 0, null: false
    t.bigint "max_discount_cents"
    t.bigint "min_order_cents", default: 0, null: false
    t.string "name", null: false
    t.integer "per_client_limit"
    t.integer "priority", default: 0, null: false
    t.integer "scope_type", default: 0, null: false
    t.datetime "starts_at"
    t.integer "total_usage_count", default: 0, null: false
    t.integer "total_usage_limit"
    t.datetime "updated_at", null: false
    t.integer "valid_weekdays", default: [], null: false, array: true
    t.integer "validity_mode", default: 0, null: false
    t.index ["account_id", "active", "kind"], name: "idx_promotions_account_active_kind"
    t.index ["account_id", "code"], name: "uniq_promotions_account_code", unique: true, where: "((code IS NOT NULL) AND (discarded_at IS NULL))"
    t.index ["account_id"], name: "index_promotions_on_account_id"
    t.index ["discarded_at"], name: "index_promotions_on_discarded_at"
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
    t.boolean "is_removable", default: false, null: false
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

  create_table "recipe_option_groups", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.integer "kind", default: 0, null: false
    t.string "label", null: false
    t.integer "max_length"
    t.integer "position"
    t.bigint "recipe_id", null: false
    t.boolean "required", default: false, null: false
    t.string "sub"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_recipe_option_groups_on_account_id"
    t.index ["discarded_at"], name: "index_recipe_option_groups_on_discarded_at"
    t.index ["recipe_id", "position"], name: "index_recipe_option_groups_on_recipe_id_and_position"
    t.index ["recipe_id"], name: "index_recipe_option_groups_on_recipe_id"
  end

  create_table "recipe_options", force: :cascade do |t|
    t.string "color_hex"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.boolean "is_default", default: false, null: false
    t.string "label", null: false
    t.integer "position"
    t.bigint "price_delta_cents", default: 0, null: false
    t.bigint "recipe_option_group_id", null: false
    t.string "sub"
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_recipe_options_on_discarded_at"
    t.index ["recipe_option_group_id", "position"], name: "index_recipe_options_on_recipe_option_group_id_and_position"
    t.index ["recipe_option_group_id"], name: "index_recipe_options_on_recipe_option_group_id"
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
    t.integer "lead_time_hours", default: 0, null: false
    t.string "name", null: false
    t.bigint "packaging_cents", default: 0, null: false
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
    t.index ["name"], name: "idx_recipes_name_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "schedules", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.integer "lead_time_minutes", default: 0, null: false
    t.integer "order_mode", default: 0, null: false
    t.datetime "updated_at", null: false
    t.text "vacation_message"
    t.date "vacation_until"
    t.index ["account_id"], name: "index_schedules_on_account_id", unique: true
    t.index ["vacation_until"], name: "idx_schedules_vacation_until", where: "(vacation_until IS NOT NULL)"
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

  create_table "stock_movements", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "ingredient_id", null: false
    t.text "note"
    t.decimal "quantity", precision: 14, scale: 3, null: false
    t.string "source", null: false
    t.bigint "source_id"
    t.string "source_type"
    t.string "unit", null: false
    t.bigint "unit_cost_cents_at_movement"
    t.datetime "updated_at", null: false
    t.index ["account_id", "ingredient_id", "created_at"], name: "idx_stock_movements_account_ingredient_time"
    t.index ["account_id"], name: "index_stock_movements_on_account_id"
    t.index ["ingredient_id"], name: "index_stock_movements_on_ingredient_id"
    t.index ["source_type", "source_id"], name: "idx_stock_movements_source"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "cancel_at_period_end", default: false, null: false
    t.datetime "comp_expires_at"
    t.bigint "comp_granted_by_id"
    t.text "comp_reason"
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.integer "plan", default: 0, null: false
    t.integer "source", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_subscriptions_on_account_id", unique: true
    t.index ["comp_expires_at"], name: "idx_subscriptions_comp_expires_at", where: "(comp_expires_at IS NOT NULL)"
    t.index ["comp_granted_by_id"], name: "index_subscriptions_on_comp_granted_by_id"
    t.index ["source"], name: "index_subscriptions_on_source"
    t.index ["stripe_customer_id"], name: "index_subscriptions_on_stripe_customer_id", unique: true, where: "(stripe_customer_id IS NOT NULL)"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true, where: "(stripe_subscription_id IS NOT NULL)"
  end

  create_table "subscriptions_dismissed_hints", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "dismissed_at", null: false
    t.string "hint_key", null: false
    t.datetime "redismiss_at"
    t.datetime "updated_at", null: false
    t.index ["account_id", "hint_key"], name: "idx_dismissed_hints_account_key", unique: true
    t.index ["account_id"], name: "index_subscriptions_dismissed_hints_on_account_id"
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
  add_foreign_key "batch_consumptions", "batches"
  add_foreign_key "batches", "accounts"
  add_foreign_key "batches", "recipes"
  add_foreign_key "categories", "accounts"
  add_foreign_key "clients", "accounts"
  add_foreign_key "fixed_cost_categories", "accounts"
  add_foreign_key "fixed_costs", "accounts"
  add_foreign_key "fixed_costs", "fixed_cost_categories"
  add_foreign_key "ingredients", "accounts"
  add_foreign_key "ingredients", "categories"
  add_foreign_key "order_items", "batches", column: "consumed_batch_id", on_delete: :nullify
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "recipes"
  add_foreign_key "orders", "accounts"
  add_foreign_key "orders", "clients"
  add_foreign_key "payments", "orders"
  add_foreign_key "promotion_categories", "categories", on_delete: :cascade
  add_foreign_key "promotion_categories", "promotions", on_delete: :cascade
  add_foreign_key "promotion_recipes", "promotions", on_delete: :cascade
  add_foreign_key "promotion_recipes", "recipes", on_delete: :cascade
  add_foreign_key "promotion_redemptions", "clients", on_delete: :nullify
  add_foreign_key "promotion_redemptions", "orders"
  add_foreign_key "promotion_redemptions", "promotions"
  add_foreign_key "promotions", "accounts"
  add_foreign_key "purchase_items", "ingredients", on_delete: :cascade
  add_foreign_key "purchase_items", "purchases", on_delete: :cascade
  add_foreign_key "purchases", "accounts"
  add_foreign_key "purchases", "suppliers", on_delete: :nullify
  add_foreign_key "recipe_components", "recipes"
  add_foreign_key "recipe_option_groups", "accounts"
  add_foreign_key "recipe_option_groups", "recipes"
  add_foreign_key "recipe_options", "recipe_option_groups"
  add_foreign_key "recipes", "accounts"
  add_foreign_key "recipes", "categories"
  add_foreign_key "schedules", "accounts"
  add_foreign_key "sessions", "users"
  add_foreign_key "stock_movements", "accounts"
  add_foreign_key "stock_movements", "ingredients"
  add_foreign_key "subscriptions", "accounts"
  add_foreign_key "subscriptions", "users", column: "comp_granted_by_id", on_delete: :nullify
  add_foreign_key "subscriptions_dismissed_hints", "accounts"
  add_foreign_key "supplier_ingredients", "ingredients", on_delete: :cascade
  add_foreign_key "supplier_ingredients", "suppliers", on_delete: :cascade
  add_foreign_key "suppliers", "accounts"
  add_foreign_key "users", "accounts"
end
