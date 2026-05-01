namespace :dev do
  desc "Bootstrap realistic development data — 8 Hermosillo kitchens with full operational history."
  task bootstrap: :environment do
    unless Rails.env.development? || ENV["ALLOW_BOOTSTRAP"] == "1"
      abort "dev:bootstrap requires ALLOW_BOOTSTRAP=1 outside development"
    end

    require_relative "../dev_bootstrap/runner"
    DevBootstrap::Runner.call
  end
end
