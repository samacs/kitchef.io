module DevBootstrap
  module Seeders
    class FixedCostsSeeder < Seeder
      def initialize(kitchen_defs, accounts)
        @kitchen_defs = kitchen_defs
        @accounts = accounts
      end

      def call
        @kitchen_defs.each do |kd|
          next if kd[:fixed_costs].blank?

          account = @accounts[kd[:key]]
          log "  fixed costs for #{account.name} (#{kd[:fixed_costs].size})"

          kd[:fixed_costs].each do |fc|
            cat = account.fixed_cost_categories.kept.find_by(name: fc[:category])
            next unless cat

            account.fixed_costs.create!(
              fixed_cost_category: cat,
              amount_cents:        cents(fc[:amount]),
              recurrence:          fc[:recurrence],
              start_date:          (kd[:history_days] + 5).days.ago.to_date,
              notes:               ""
            )
          end
        end
      end
    end
  end
end
