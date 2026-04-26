module DevBootstrap
  module Seeders
    class SuppliersSeeder < Seeder
      def initialize(kitchen_defs, accounts)
        @kitchen_defs = kitchen_defs
        @accounts = accounts
      end

      def call
        @kitchen_defs.each do |kd|
          next if kd[:suppliers].blank?

          account = @accounts[kd[:key]]
          log "  suppliers for #{account.name} (#{kd[:suppliers].size})"

          kd[:suppliers].each do |s|
            account.suppliers.create!(
              name:           s[:name],
              phone:          sample_phone,
              colonia:        s[:colonia],
              city:           "Hermosillo",
              street_address: Faker::Address.street_address
            )
          end
        end
      end
    end
  end
end
