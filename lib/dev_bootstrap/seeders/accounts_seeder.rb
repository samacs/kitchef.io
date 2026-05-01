module DevBootstrap
  module Seeders
    class AccountsSeeder < Seeder
      def initialize(kitchen_defs)
        @kitchen_defs = kitchen_defs
        @accounts = {}
      end

      def call
        @kitchen_defs.each do |kd|
          log "==> #{kd[:account][:name]}"
          account = create_account(kd)
          @accounts[kd[:key]] = account
        end
        @accounts
      end

      private

      def create_account(kd)
        a = kd[:account]
        o = kd[:owner]

        user = User.create!(
          email_address:     o[:email],
          password:          Kitchens::PASSWORD,
          first_name:        o[:first],
          last_name:         o[:last],
          phone:             sample_phone,
          terms_accepted_at: (kd[:history_days] + 5).days.ago
        )

        account = Account.create!(
          owner:          user,
          name:           a[:name],
          time_zone:      Kitchens::HERMOSILLO_TZ,
          street_address: a[:street_address],
          latitude:       a[:lat],
          longitude:      a[:lon],
          geocoded_at:    Time.current,
          settings: {
            use_composable_recipes:        kd[:mode] == :advanced,
            composable_recipes_unlocked_at: (kd[:mode] == :advanced ? kd[:history_days].days.ago : nil),
            onboarding_completed:          true,
            default_packaging_cents:       a[:packaging_cents] || 0,
            payment_settings: {
              accepts_cash:            a[:accepts_cash],
              accepts_transfer:        a[:accepts_transfer],
              accepts_card:            a.fetch(:accepts_card, false),
              transfer_holder:         a[:transfer_holder].to_s,
              transfer_bank:           a[:transfer_bank].to_s,
              transfer_clabe:          a[:transfer_clabe].to_s,
              transfer_account_number: a[:transfer_account_number].to_s,
              card_instructions:       a[:card_instructions].to_s,
              accepts_tips:            a.fetch(:accepts_tips, true),
              tip_presets_pct:         a[:tip_presets] || [ 10, 15, 20 ]
            }
          },
          branding: {
            palette:           a[:palette] || "bosque",
            secondary_palette: a[:secondary] || "terracota"
          },
          public_profile: {
            tagline:              a[:tagline],
            description:          a[:description],
            phone:                "+52 #{sample_phone}",
            whatsapp:             "+52 #{sample_phone}",
            colonia:              a[:colonia],
            city:                 a[:city],
            fulfillment_types:    a[:fulfillment] || "pickup,delivery",
            delivery_zones:       a[:delivery_zones].to_s,
            show_pickup_address:  a.fetch(:show_pickup_address, false),
            pickup_reminder_hours: 4
          }
        )

        plan = a[:plan] || :free
        source = plan == :free ? :free : :sandbox
        account.create_subscription!(plan: plan, status: :active, source: source)

        ImageCache.attach(account, :cover_photo, slug: "#{kd[:key]}-cover", unsplash_id: kd[:cover_photo_id])
        ImageCache.attach(account, :logo, slug: "#{kd[:key]}-logo", unsplash_id: kd[:logo_photo_id])

        account
      end
    end
  end
end
