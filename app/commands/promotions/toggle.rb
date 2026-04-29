module Promotions
  class Toggle < ApplicationCommand
    option :promotion

    def call
      promotion.update!(active: !promotion.active?)
      success(promotion)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, object: promotion, errors: e.record.errors)
    end
  end
end
