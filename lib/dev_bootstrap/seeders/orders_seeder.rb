module DevBootstrap
  module Seeders
    class OrdersSeeder < Seeder
      STATE_CHAINS = {
        placed:         [],
        confirmed:      %i[confirm],
        in_production:  %i[confirm start_production],
        ready:          %i[confirm start_production mark_ready],
        delivered:      %i[confirm start_production mark_ready deliver],
        delivered_paid: %i[confirm start_production mark_ready deliver]
      }.freeze

      def initialize(kitchen_defs, accounts)
        @kitchen_defs = kitchen_defs
        @accounts = accounts
      end

      def call
        @kitchen_defs.each do |kd|
          account = @accounts[kd[:key]]
          count = order_count_for(kd)
          log "  orders for #{account.name} (#{count})"

          recipes = account.recipes.kept.saleable.to_a
          clients = account.clients.to_a
          next if recipes.empty? || clients.empty?

          count.times do |i|
            create_order(account, kd, recipes, clients, i)
          end
        end
      end

      private

      def order_count_for(kd)
        case kd[:history_days]
        when 25.. then 40
        when 10.. then 18
        when 5..  then 8
        else 4
        end
      end

      def create_order(account, kd, recipes, clients, idx)
        client  = clients.sample
        day_offset = rand(-kd[:history_days]..3)
        delivery_date = Date.current + day_offset
        is_delivery = account.public_profile.offers_delivery? && idx.even?

        payment_method = if account.payment_settings.any_method_enabled?
                           account.payment_settings.enabled_methods.sample
        end
        tip = account.payment_settings.accepts_tips ? [ 0, 0, 1500, 2000, 3000 ].sample : 0

        order = account.orders.create!(
          client:            client,
          delivery_date:     delivery_date,
          delivery_type:     is_delivery ? :delivery : :pickup,
          delivery_mode:     :scheduled,
          delivery_start_time: (start_t = [ 600, 720, 780 ].sample),
          delivery_end_time:   start_t + [ 120, 180, 240 ].sample,
          source:            %i[storefront manual whatsapp].sample,
          colonia:           client.colonia,
          city:              client.city,
          delivery_address:  (is_delivery ? "Calle #{Faker::Address.street_name} #{rand(1..500)}" : nil),
          payment_method:    payment_method,
          tip_cents:         tip,
          terms_accepted_at: Time.current
        )

        item_count = rand(1..4)
        item_count.times do
          recipe = recipes.sample
          qty = [ 1, 1, 2, 3 ].sample
          order.items.create!(
            recipe:           recipe,
            quantity:         qty,
            unit_price_cents: recipe.sale_price_cents,
            unit_cost_cents:  recipe.cost_cents_cached.to_i.positive? ? recipe.cost_cents_cached : (recipe.sale_price_cents * 0.35).to_i
          )
        end

        subtotal = order.items.sum { |it| it.unit_price_cents * it.quantity }
        order.update_columns(
          subtotal_cents: subtotal,
          total_cents:    subtotal + order.packaging_cents.to_i + order.tip_cents.to_i,
          balance_cents:  subtotal + order.packaging_cents.to_i + order.tip_cents.to_i
        )

        advance_order_state(order, delivery_date)
      end

      def advance_order_state(order, delivery_date)
        if delivery_date > Date.current
          return
        elsif delivery_date == Date.current
          chosen = %i[placed confirmed in_production].sample
        else
          chosen = %i[confirmed in_production ready delivered delivered_paid].sample
        end

        STATE_CHAINS[chosen].each { |event| order.send("#{event}!") }
        order.mark_paid! if chosen == :delivered_paid
      end
    end
  end
end
