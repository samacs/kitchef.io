module DeliveryMethods
  class TurboBroadcast < Noticed::DeliveryMethod
    def deliver
      Turbo::StreamsChannel.broadcast_refresh_to(recipient, :notifications)
    end
  end
end
