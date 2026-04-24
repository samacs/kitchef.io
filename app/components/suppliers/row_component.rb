module Suppliers
  # Single row in the /proveedores index. Mirrors Clients::RowComponent
  # structure — name + phone + colonia + ingredient count + last-bought
  # relative date, with edit + delete affordances.
  class RowComponent < ApplicationComponent
    option :supplier

    def edit_path
      helpers.edit_supplier_path(supplier)
    end

    def phone_display
      supplier.display_phone
    end

    def colonia_display
      [ supplier.colonia, supplier.city ].compact_blank.join(", ").presence
    end

    def ingredient_count
      supplier.ingredient_count
    end

    def last_bought_label
      date = supplier.last_bought_on
      return nil if date.blank?
      helpers.l(date, format: :long)
    end
  end
end
