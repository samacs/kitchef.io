module Dashboards
  class RecentOrdersComponent < ApplicationComponent
    option :orders # ActiveRecord::Relation (limit 5)

    def empty? = orders.empty?
  end
end
