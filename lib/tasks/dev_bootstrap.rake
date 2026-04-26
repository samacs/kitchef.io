namespace :dev do
  desc "Bootstrap realistic development data — 8 Hermosillo kitchens with full operational history. Development only."
  task bootstrap: :environment do
    abort "dev:bootstrap is only for development!" unless Rails.env.development?

    require_relative "../dev_bootstrap/runner"
    DevBootstrap::Runner.call
  end
end
