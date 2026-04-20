module Clients
  # Single row in the clients index table. Knows how to render the name
  # link, phone, colonia, and pedidos count for the row's client.
  class RowComponent < ApplicationComponent
    option :client

    def name
      client.name.presence || client.first_name
    end

    def phone_display
      return nil if client.phone.blank?

      Phonelib.parse(client.phone, "MX").international.presence || client.phone
    end

    def orders_count
      client.orders.kept.count
    end

    def edit_path
      helpers.edit_client_path(client)
    end
  end
end
