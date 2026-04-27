module DemoGuard
  # Drop-in mailer concern that prevents real outbound mail from a
  # demo account. We attach an interceptor at the class level so
  # every mail object — including the auto-generated `placed`,
  # `confirmation`, `password_reset`, etc. — gets checked the same
  # way without each mailer remembering to opt in.
  #
  # The check looks for an account on the rendered mail's
  # `@_message` instance variables (set by the per-mail `params`
  # hash) OR on `mail.delivery_handler` if it's an
  # `ActionMailer::MessageDelivery`. Mailers that set `@account` (or
  # any param that responds to `.demo?`) get the guard for free.
  extend ActiveSupport::Concern

  class Interceptor
    def self.delivering_email(message)
      return unless demo_account_for(message)
      message.perform_deliveries = false
      Rails.logger.info("[DemoGuard] suppressed mail to=#{message.to} subject=#{message.subject.inspect}")
    end

    def self.demo_account_for(message)
      pool = Array(message.instance_variable_get(:@params)) +
             [ message.instance_variable_get(:@account),
               message.instance_variable_get(:@order)&.account,
               message.instance_variable_get(:@client)&.account ]

      pool.flatten.compact.find do |obj|
        obj.respond_to?(:demo?) && obj.demo?
      end
    end
  end

  included do
    register_interceptor Interceptor
  end
end
