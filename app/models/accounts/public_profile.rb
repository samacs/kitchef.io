module Accounts
  # Per-account public-facing profile copy, persisted as a JSONB column on
  # accounts.public_profile and typed via the `store_model` gem.
  #
  # Every attribute is optional so the operator can finish onboarding with
  # just a kitchen name + slug and come back to polish the rest later.
  class PublicProfile
    include StoreModel::Model

    DESCRIPTION_MAX = 560
    FULFILLMENT     = %w[pickup delivery].freeze
    DEFAULT_PICKUP_REMINDER_HOURS = 4

    # Narrative copy shown on the storefront hero + about block.
    attribute :description, :string, default: ""
    attribute :tagline,     :string, default: ""

    # Contact details. `phone` and `whatsapp` are stored raw; the view layer
    # normalizes via `Phone::NormalizeMx` before rendering `wa.me/…` links.
    attribute :phone,     :string, default: ""
    attribute :whatsapp,  :string, default: ""
    attribute :instagram, :string, default: ""

    # Location metadata surfaced in the hero ("Condesa · CDMX") and the
    # storefront info strip.
    attribute :colonia, :string, default: ""
    attribute :city,    :string, default: ""

    # Comma-separated subset of `FULFILLMENT`. Defaults to pickup+delivery
    # so a brand-new kitchen can take both without touching settings. The
    # storefront checkout form reads `#fulfillment_type_options` (see
    # helper below) so only the operator's picked types render.
    attribute :fulfillment_types, :string, default: "pickup,delivery"

    # Comma-separated colonia names shown on the storefront info strip
    # (stays a flat string for form simplicity; promoted to jsonb-array
    # when the delivery-slot UI lands in a later phase).
    attribute :delivery_zones, :string, default: ""

    # Free-text note shown to the customer on the confirmation page
    # ("Te contactaré por WhatsApp para confirmar anticipo…"). No payment
    # processing in v1; this is the handoff note.
    attribute :payment_notes, :string, default: ""

    # Pickup pedidos in `ready` longer than this many hours trigger a
    # `PickupReminderJob`. Operator-configurable, clamped 0..24.
    attribute :pickup_reminder_hours, :integer, default: DEFAULT_PICKUP_REMINDER_HOURS

    validates :description, length: { maximum: DESCRIPTION_MAX }
    validates :tagline,     length: { maximum: 80 }
    validates :pickup_reminder_hours,
      numericality: { only_integer: true, in: 0..24 }

    # --- Fulfillment helpers --------------------------------------------
    #
    # `fulfillment_types` is stored as a comma-separated string so the
    # settings form can use plain inputs. These helpers parse/filter it
    # against the FULFILLMENT allow-list so a stale DB value (for instance
    # an old enum that no longer exists) can't leak into the storefront.
    def fulfillment_type_list
      fulfillment_types.to_s.split(",").map(&:strip).reject(&:empty?) & FULFILLMENT
    end

    def offers_pickup?   = fulfillment_type_list.include?("pickup")
    def offers_delivery? = fulfillment_type_list.include?("delivery")

    def delivery_zones_list
      delivery_zones.to_s.split(",").map(&:strip).reject(&:empty?)
    end
  end
end
