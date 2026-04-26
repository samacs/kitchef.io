module DevBootstrap
  module Seeders
    # Sonoran first names + last names for realistic Hermosillo clients.
    class ClientsSeeder < Seeder
      FIRST_NAMES = %w[
        Ana Beatriz Carmen Diana Elena Fernanda Gabriela
        Héctor Iván José Luis María Natalia Óscar
        Patricia Raquel Sofía Teresa Valentina Ximena
      ].freeze

      LAST_NAMES = %w[
        Acuña Durazo Encinas Félix Grijalva López
        Morales Navarro Ochoa Quiroga Rascón Siqueiros
        Tapia Valenzuela Yépez Zúñiga Coronado Figueroa
      ].freeze

      COLONIAS = %w[
        Centro Centenario Pitic Modelo Villa\ de\ Seris
        Las\ Quintas Sahuaro Olivares Bachoco San\ Benito
      ].freeze

      def initialize(kitchen_defs, accounts)
        @kitchen_defs = kitchen_defs
        @accounts = accounts
      end

      def call
        @kitchen_defs.each do |kd|
          account = @accounts[kd[:key]]
          count = client_count_for(kd)
          log "  clients for #{account.name} (#{count})"

          count.times do
            first = FIRST_NAMES.sample
            last  = LAST_NAMES.sample
            account.clients.create!(
              first_name: first,
              last_name:  last,
              phone:      sample_phone,
              email:      sample_email(first, last),
              colonia:    COLONIAS.sample,
              city:       "Hermosillo"
            )
          end
        end
      end

      private

      def client_count_for(kd)
        case kd[:history_days]
        when 25.. then 20
        when 10.. then 12
        else 6
        end
      end
    end
  end
end
