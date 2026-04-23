module Recipes
  # Nested disclosure widget that renders a recipe's cost tree.
  # Each recipe-typed node becomes a <details>/<summary>, each
  # ingredient-typed node becomes a leaf row. Pure server render — no
  # JS — so it prints cleanly and works without Stimulus.
  #
  #   <%= render Recipes::CostTreeComponent.new(node: @cost_tree_root) %>
  class CostTreeComponent < ApplicationComponent
    option :node
    option :depth, default: -> { 0 }

    def format_money
      helpers.humanized_money_with_symbol(node.money)
    end

    def unit_label
      I18n.t("units.#{node.unit}", default: node.unit.to_s)
    end
  end
end
