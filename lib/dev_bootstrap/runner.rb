require "database_cleaner/active_record"

require_relative "image_cache"
require_relative "seeder"
require_relative "kitchens"
require_relative "seeders/accounts_seeder"
require_relative "seeders/ingredients_seeder"
require_relative "seeders/suppliers_seeder"
require_relative "seeders/recipes_seeder"
require_relative "seeders/clients_seeder"
require_relative "seeders/orders_seeder"
require_relative "seeders/purchases_seeder"
require_relative "seeders/fixed_costs_seeder"
require_relative "seeders/batches_seeder"

module DevBootstrap
  class Runner
    def self.call
      new.call
    end

    def call
      abort "dev:bootstrap is development-only!" unless Rails.env.development?

      puts "\n=== dev:bootstrap — 8 Hermosillo kitchens ==="
      started = Time.current

      nuke_database
      Faker::Config.locale = "es-MX"

      kitchen_defs = Kitchens::ALL
      accounts = Seeders::AccountsSeeder.call(kitchen_defs)

      puts "\n--- Ingredients + suppliers ---"
      Seeders::IngredientsSeeder.call(kitchen_defs, accounts)
      Seeders::SuppliersSeeder.call(kitchen_defs, accounts)

      puts "\n--- Recipes + photos ---"
      Seeders::RecipesSeeder.call(kitchen_defs, accounts)

      puts "\n--- Clients ---"
      Seeders::ClientsSeeder.call(kitchen_defs, accounts)

      puts "\n--- Orders ---"
      Seeders::OrdersSeeder.call(kitchen_defs, accounts)

      puts "\n--- Purchases ---"
      Seeders::PurchasesSeeder.call(kitchen_defs, accounts)

      puts "\n--- Fixed costs ---"
      Seeders::FixedCostsSeeder.call(kitchen_defs, accounts)

      puts "\n--- Batches (advanced kitchens only) ---"
      Seeders::BatchesSeeder.call(kitchen_defs, accounts)

      elapsed = (Time.current - started).round(1)
      puts "\n=== done in #{elapsed}s ==="
      print_summary(kitchen_defs, accounts)
    end

    private

    def nuke_database
      puts "==> wiping development database"

      Session.delete_all rescue nil
      Account.find_each(&:destroy)
      User.delete_all

      # Truncate everything else cleanly.
      DatabaseCleaner.strategy = :truncation, {
        except: %w[ar_internal_metadata schema_migrations]
      }
      DatabaseCleaner.clean

      ActiveStorage::Blob.find_each do |blob|
        blob.purge
      rescue StandardError
        nil
      end
    end

    def print_summary(kitchen_defs, accounts)
      rows = kitchen_defs.filter_map do |kd|
        a = accounts[kd[:key]]&.reload
        next unless a

        saleable = a.recipes.kept.saleable.count
        internal = a.recipes.kept.where(is_saleable: false).count
        recipes  = internal.positive? ? "#{saleable}+#{internal}" : saleable.to_s
        inv = a.inventory_enabled? ? a.settings.inventory_settings.oversell_policy : "-"
        mto = a.recipes.kept.where(made_to_order: true).count

        {
          name:    a.name,
          email:   a.owner.email_address,
          mode:    kd[:mode].to_s,
          history: "#{kd[:history_days]}d",
          recipes: recipes,
          orders:  a.orders.count,
          clients: a.clients.count,
          inv:     inv,
          mto:     mto
        }
      end

      col_widths = {
        name:    [ 7, rows.map { |r| r[:name].length }.max ].max,
        email:   [ 5, rows.map { |r| r[:email].length }.max ].max,
        mode:    8,
        history: 7,
        recipes: 7,
        orders:  6,
        clients: 7,
        inv:     5,
        mto:     3
      }

      header = format(
        "  %-#{col_widths[:name]}s  %-#{col_widths[:email]}s  %-#{col_widths[:mode]}s  %#{col_widths[:history]}s  %#{col_widths[:recipes]}s  %#{col_widths[:orders]}s  %#{col_widths[:clients]}s  %-#{col_widths[:inv]}s  %#{col_widths[:mto]}s",
        "Kitchen", "Email", "Mode", "History", "Recipes", "Orders", "Clients", "Inv", "MTO"
      )
      separator = "  " + col_widths.values.map { |w| "-" * w }.join("  ")

      puts ""
      puts header
      puts separator
      rows.each do |r|
        puts format(
          "  %-#{col_widths[:name]}s  %-#{col_widths[:email]}s  %-#{col_widths[:mode]}s  %#{col_widths[:history]}s  %#{col_widths[:recipes]}s  %#{col_widths[:orders]}s  %#{col_widths[:clients]}s  %-#{col_widths[:inv]}s  %#{col_widths[:mto]}s",
          r[:name], r[:email], r[:mode], r[:history], r[:recipes], r[:orders], r[:clients], r[:inv], r[:mto]
        )
      end
      puts separator
      puts "  Password: #{Kitchens::PASSWORD}"
      puts ""
    end
  end
end
