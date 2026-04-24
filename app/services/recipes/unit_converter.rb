module Recipes
  # Strict unit conversion between compatible kitchen units. No density
  # guessing — a kg of flour is not a liter of flour, so cross-type
  # conversions raise and the form layer surfaces the error.
  #
  #   Recipes::UnitConverter.convert(quantity: 1500, from: "g", to: "kg") # => 1.5
  #   Recipes::UnitConverter.convert(quantity: 2,    from: "kg", to: "ml") # raises
  class UnitConverter
    class IncompatibleUnits < StandardError
      def initialize(from:, to:)
        super("Cannot convert #{from} to #{to}: different measurement families")
      end
    end

    # Each unit lives in one family and has a conversion factor to the
    # family's canonical unit. `serving` is treated as a count-family
    # alias for `piece` so a recipe yielding 4 servings can be pulled
    # from as 2 pieces (half the batch cost).
    FAMILIES = {
      "g"       => { family: :mass,   per_canonical: BigDecimal("0.001") },
      "kg"      => { family: :mass,   per_canonical: BigDecimal("1") },
      "ml"      => { family: :volume, per_canonical: BigDecimal("0.001") },
      "l"       => { family: :volume, per_canonical: BigDecimal("1") },
      "piece"   => { family: :count,  per_canonical: BigDecimal("1") },
      "serving" => { family: :count,  per_canonical: BigDecimal("1") }
    }.freeze

    def self.convert(quantity:, from:, to:)
      return BigDecimal(quantity.to_s) if from == to

      src = FAMILIES.fetch(from.to_s) { raise IncompatibleUnits.new(from: from, to: to) }
      dst = FAMILIES.fetch(to.to_s)   { raise IncompatibleUnits.new(from: from, to: to) }
      raise IncompatibleUnits.new(from: from, to: to) if src[:family] != dst[:family]

      canonical = BigDecimal(quantity.to_s) * src[:per_canonical]
      canonical / dst[:per_canonical]
    end

    # True when two units can be converted between each other. The form
    # layer uses this to build the unit dropdown for a given ingredient
    # or recipe (offer kg/g for a kg-tracked ingredient; l/ml for a
    # l-tracked one; piece/serving for count-tracked).
    def self.compatible?(from, to)
      return false unless FAMILIES.key?(from.to_s) && FAMILIES.key?(to.to_s)

      FAMILIES[from.to_s][:family] == FAMILIES[to.to_s][:family]
    end

    # Returns the list of units compatible with the given base unit,
    # ordered by descending magnitude so dropdowns land with the coarse
    # unit on top (kg above g).
    def self.compatible_units_for(base_unit)
      base = FAMILIES[base_unit.to_s]
      return [ base_unit.to_s ] unless base

      FAMILIES.select { |_, meta| meta[:family] == base[:family] }
              .sort_by { |_, meta| -meta[:per_canonical] }
              .map(&:first)
    end
  end
end
