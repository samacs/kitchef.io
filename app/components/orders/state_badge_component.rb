module Orders
  # Maps an Order AASM state to a Ui::BadgeComponent token. Keeps the
  # mapping in one place so kanban columns, cards, and the dashboard
  # pickup all share the same color story.
  class StateBadgeComponent < ApplicationComponent
    STATE_TOKENS = {
      "placed"        => :nuevo,
      "confirmed"     => :default,
      "in_production" => :en_produccion,
      "ready"         => :listo,
      "en_route"      => :en_produccion,
      "delivered"     => :listo,
      "canceled"      => :atrasado
    }.freeze

    option :state

    def call
      render Ui::BadgeComponent.new(
        label:  I18n.t("order.state.#{state}"),
        status: STATE_TOKENS.fetch(state.to_s, :default),
        dot:    true
      )
    end
  end
end
