module Dashboards
  class TodayCardComponent < ApplicationComponent
    option :plan   # Production::DailyPlan::Result
    option :today

    def empty?          = plan.empty?
    def placed_count    = plan.counts.fetch("placed", 0)
    def confirmed_count = plan.counts.fetch("confirmed", 0)
    def cooking_count   = plan.counts.fetch("in_production", 0)
    def ready_count     = plan.counts.fetch("ready", 0)
    def en_route_count  = plan.counts.fetch("en_route", 0)
    def delivered_count = plan.counts.fetch("delivered", 0)

    def total_count
      plan.counts.values.sum
    end

    def pending_count
      placed_count + confirmed_count + cooking_count
    end

    def done_count
      ready_count + en_route_count + delivered_count
    end
  end
end
