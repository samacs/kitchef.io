class Search::Omnisearch < ApplicationQuery
  option :account
  option :term
  option :limit_per_group, default: -> { 5 }

  Result = Data.define(:groups)
  Group  = Data.define(:kind, :items)
  Item   = Data.define(:record, :title, :subtitle, :score)

  SEARCHABLE_GROUPS = {
    clients:     { model: :clients,     scope: :kept },
    recipes:     { model: :recipes,     scope: :kept },
    ingredients: { model: :ingredients, scope: :kept }
  }.freeze

  def call
    return Result.new(groups: []) if term.blank?

    groups = SEARCHABLE_GROUPS.filter_map do |kind, config|
      items = search_group(kind, config)
      Group.new(kind: kind, items: items) if items.any?
    end

    orders_group = search_orders
    groups.unshift(orders_group) if orders_group

    Result.new(groups: groups)
  end

  private

  def search_group(kind, config)
    relation = account.public_send(config[:model])
    relation = relation.public_send(config[:scope]) if config[:scope]
    records  = relation.omnisearch(term, limit: limit_per_group)

    records.map { |r| build_item(kind, r) }
  end

  def search_orders
    q = term.downcase.strip
    escaped = q.gsub("%", "\\%").gsub("_", "\\_")
    sanitized = Order.connection.quote("%#{escaped}%")

    orders = account.orders.kept
      .left_joins(:client)
      .where(
        "LOWER(clients.first_name) LIKE #{sanitized} " \
        "OR LOWER(clients.last_name) LIKE #{sanitized} " \
        "OR LOWER(clients.phone_normalized) LIKE #{sanitized} " \
        "OR CAST(orders.id AS TEXT) LIKE #{sanitized}"
      )
      .order(delivery_date: :desc)
      .limit(limit_per_group)
      .includes(:client)

    items = orders.map { |o| build_item(:orders, o) }
    items.any? ? Group.new(kind: :orders, items: items) : nil
  end

  def build_item(kind, record)
    case kind
    when :clients
      Item.new(
        record: record,
        title: record.name.full,
        subtitle: record.phone_normalized,
        score: record.try(:search_score)
      )
    when :recipes
      Item.new(
        record: record,
        title: record.name,
        subtitle: record.is_saleable ? humanized_price(record.sale_price_cents) : nil,
        score: record.try(:search_score)
      )
    when :ingredients
      Item.new(
        record: record,
        title: record.name,
        subtitle: "#{humanized_price(record.unit_cost_cents)} / #{record.unit}",
        score: record.try(:search_score)
      )
    when :orders
      client_name = record.client&.name&.full
      Item.new(
        record: record,
        title: "##{record.id} · #{client_name || 'Sin cliente'}",
        subtitle: I18n.l(record.delivery_date, format: :short),
        score: nil
      )
    end
  end

  def humanized_price(cents)
    return nil unless cents&.positive?

    Money.new(cents, "MXN").format
  end
end
