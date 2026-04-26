module Accounts
  class PaymentSettings
    include StoreModel::Model

    attribute :accepts_cash,     :boolean, default: true
    attribute :accepts_transfer, :boolean, default: false
    attribute :accepts_card,     :boolean, default: false

    attribute :transfer_holder,         :string, default: ""
    attribute :transfer_bank,           :string, default: ""
    attribute :transfer_clabe,          :string, default: ""
    attribute :transfer_account_number, :string, default: ""

    attribute :card_instructions, :string, default: ""

    # Tip collection toggle. Off-by-default operators (food trucks,
    # comida-corrida, anyone whose customers don't tip) hide the entire
    # propina card from the storefront checkout. Defaults to true so
    # existing kitchens keep the propina UI they signed up with.
    attribute :accepts_tips, :boolean, default: true

    attribute :tip_presets_pct, default: -> { [ 10, 15, 20 ] }

    validates :transfer_clabe,
      format: { with: /\A\d{18}\z/ },
      allow_blank: true

    validate :tip_presets_are_valid

    def any_method_enabled?
      accepts_cash || accepts_transfer || accepts_card
    end

    def enabled_methods
      [].tap do |m|
        m << :cash     if accepts_cash
        m << :transfer if accepts_transfer
        m << :card     if accepts_card
      end
    end

    def accepts_method?(method)
      case method.to_s
      when "cash"     then accepts_cash
      when "transfer" then accepts_transfer
      when "card"     then accepts_card
      else false
      end
    end

    private

    def tip_presets_are_valid
      presets = tip_presets_pct
      return if presets.blank?

      unless presets.is_a?(Array) && presets.size <= 3
        errors.add(:tip_presets_pct, :invalid)
        return
      end

      unless presets.all? { |v| v.is_a?(Integer) && v.between?(1, 100) }
        errors.add(:tip_presets_pct, :invalid)
        return
      end

      unless presets == presets.sort
        errors.add(:tip_presets_pct, :invalid)
      end
    end
  end
end
