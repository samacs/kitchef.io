# Production mail delivery goes through Resend (`resend` gem). The mailer
# adapter Rails uses — `config.action_mailer.delivery_method = :resend` in
# production.rb — reads its API key from the gem's configuration, which we
# set here from Rails credentials. Development + test skip this entirely
# (letter_opener + ActionMailer::TestHelper respectively).
#
# Put the API key under `resend.api_key` in `rails credentials:edit`. A
# fallback to `ENV["RESEND_API_KEY"]` keeps staging/CI boxes working when
# shared credentials aren't checked in.

if Rails.env.production?
  api_key = Rails.application.credentials.dig(:resend, :api_key).presence ||
            ENV["RESEND_API_KEY"].presence

  if api_key.present?
    ::Resend.api_key = api_key
  else
    Rails.logger.warn "[mail] Resend API key missing — email delivery will raise"
  end
end
