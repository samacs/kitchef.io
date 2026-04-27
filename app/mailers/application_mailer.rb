class ApplicationMailer < ActionMailer::Base
  include DemoGuard

  # Platform-wide From: address. Kitchef owns the `kitchef.mx` domain and its
  # SPF/DKIM/DMARC records, so every outbound mail leaves from here. Kitchen
  # owners don't need deliverable SMTP — when a customer wants to reach the
  # operator back, per-mailer calls set `reply_to:` to the kitchen's contact
  # email, and the prominent WhatsApp CTA in the body covers the rest.
  PLATFORM_FROM = "no-reply@kitchef.mx".freeze

  default from: PLATFORM_FROM

  layout "mailer"
end
