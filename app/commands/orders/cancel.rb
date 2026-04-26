module Orders
  # Cancels a pedido with an attached reason. The cancel event itself is
  # AASM's, but we assign the reason columns BEFORE firing so the
  # canceled-state validation sees them. On failure (invalid reason,
  # event not fireable) the in-memory order carries the errors so the
  # drawer form can re-render with messages.
  class Cancel < ApplicationCommand
    option :order
    option :params

    def call
      return failure_with(:transition_not_allowed) unless order.aasm.may_fire_event?(:cancel)

      attrs = params.to_h.deep_symbolize_keys
      order.cancel_reason_code = attrs[:cancel_reason_code]
      order.cancel_reason_note = attrs[:cancel_reason_note]

      # Validate the reason BEFORE firing — AASM's after_cancel callback
      # stamps canceled_at via update_column, so by the time the record
      # has `canceled?` true we've already moved the wheel. Check here.
      unless reason_valid?
        return Result.new(success: false, object: order, errors: order.errors)
      end

      if order.cancel!
        release_consumption(order)
        success(order)
      else
        Result.new(success: false, object: order, errors: order.errors)
      end
    end

    # Phase 13 — when an order is canceled, release the units it had
    # claimed against any production run so they're available for the
    # next customer. Inventory ledger gets a matching restock entry per
    # consumed item.
    def release_consumption(order)
      return unless order.account.inventory_enabled?
      order.items.where.not(consumed_run_id: nil).each do |item|
        item.update_columns(consumed_run_id: nil, consumed_quantity: 0)
      end
    end

    private

    def reason_valid?
      code = order.cancel_reason_code.to_s
      if code.blank?
        order.errors.add(:cancel_reason_code, :blank)
        return false
      end
      unless Order::CANCEL_REASON_CODES.include?(code)
        order.errors.add(:cancel_reason_code, :invalid)
        return false
      end
      if code == "other" && order.cancel_reason_note.to_s.strip.empty?
        order.errors.add(:cancel_reason_note, :blank)
        return false
      end
      true
    end

    def failure_with(key)
      order.errors.add(:base, key)
      Result.new(success: false, object: order, errors: order.errors)
    end
  end
end
