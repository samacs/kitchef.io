namespace :dev do
  desc "Flag an account as a demo (default: cocina-demo) with indefinite comp-Pro. Development only."
  task :demo, [ :slug ] => :environment do |_, args|
    abort "dev:demo is only for development!" unless Rails.env.development?

    slug = args[:slug].presence || ENV.fetch("DEMO_SLUG", "cocina-demo")
    account = Account.kept.find_by(slug: slug)
    abort "No account with slug=#{slug.inspect}. Create it first via dev:bootstrap or the signup flow." if account.nil?

    account.update_column(:demo, true) unless account.demo?

    sub = account.subscription || account.create_subscription!
    granter = User.where(admin: true).first || account.owner
    sub.update!(
      source:             :comp,
      plan:               :pro_yearly,
      status:             :active,
      comp_granted_by:    granter,
      comp_reason:        "Shared public demo account",
      comp_expires_at:    nil
    )

    puts "Flagged account #{slug.inspect} as demo + indefinite comp-Pro."
    puts "Banner will appear on the operator dashboard + storefront on the next page load."
    puts "Run `bin/rails 'demo:reset[#{slug}]'` to wipe pedidos/clients/notifications + restore."
  end
end

namespace :demo do
  desc "Manually trigger Demo::ResetJob for the demo account (default: cocina-demo). Idempotent."
  task :reset, [ :slug ] => :environment do |_, args|
    slug = args[:slug].presence || ENV.fetch("DEMO_SLUG", "cocina-demo")
    Demo::ResetJob.new.perform(slug)
    puts "Demo reset for slug=#{slug.inspect} done."
  end
end
