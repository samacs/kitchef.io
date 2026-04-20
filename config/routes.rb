require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # ---- Health check / ops ----------------------------------------------
  get "up" => "rails/health#show", as: :rails_health_check

  # ---- Sidekiq Web UI --------------------------------------------------
  # Gated by AdminConstraint in production/staging (Kitchef team only). In
  # development it's open so overmind-ran workers are easy to inspect. Same
  # pattern as Agendario's config/routes/system.rb.
  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
  else
    constraints(AdminConstraint) { mount Sidekiq::Web => "/sidekiq" }
  end

  # ---- Letter Opener (dev only) ----------------------------------------
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # ---- Authentication -------------------------------------------------
  # Custom paths — `get/post` to the same URL rather than the default
  # `resource :session, path: "sign-in"` which would give us /sign-in/new.
  # One URL per form keeps the UI and marketing links predictable.
  get    "/sign-in",          to: "sessions#new",        as: :new_session
  post   "/sign-in",          to: "sessions#create",     as: :session
  delete "/sign-out",         to: "sessions#destroy",    as: :destroy_session

  get    "/sign-up",          to: "registrations#new",   as: :new_registration
  post   "/sign-up",          to: "registrations#create", as: :registration

  get    "/reset-password",            to: "passwords#new",    as: :new_password
  post   "/reset-password",            to: "passwords#create", as: :passwords
  get    "/reset-password/:token/edit", to: "passwords#edit",  as: :edit_password
  match  "/reset-password/:token",     to: "passwords#update", as: :password, via: %i[patch put]

  # ---- Marketing / public static pages ---------------------------------
  # Each path routes to StaticPagesController#show; the controller picks
  # the matching view template from the :page default. Adding a page =
  # add a view file + one line here.
  get "/pricing",       to: "static_pages#show", defaults: { page: "pricing" }
  get "/how-it-works",  to: "static_pages#show", defaults: { page: "how_it_works" }
  get "/faq",           to: "static_pages#show", defaults: { page: "faq" }
  get "/legal/:doc",    to: "static_pages#show", defaults: { page: "legal" }, as: :legal

  # ---- Root path ------------------------------------------------------
  # Constraint-based dispatch: signed-in operators land on their dashboard,
  # anonymous visitors see the marketing home page. Same URL, two handlers.
  root "dashboards#show",
    constraints: UserConstraint,
    as: :authenticated_root

  root "static_pages#show", defaults: { page: "home" }

  # ---- Platform admin (Kitchef team only) -----------------------------
  # Protected at the routing layer by AdminConstraint; a non-admin
  # (including unauthenticated) request falls through and hits the
  # storefront catch-all, which rejects "admin" (RESERVED_SLUGS).
  # Admin-level auth is therefore enforced in two layers: constraint here
  # plus require_admin in Admin::BaseController.
  constraints AdminConstraint do
    namespace :admin do
      root "dashboards#show"
    end
  end

  # ---- Authenticated operator app -------------------------------------
  # All routes live at the top level (no /panel prefix, no module scope).
  # Controllers inherit from AuthenticatedController which enforces session
  # + Current.account. Production/Reports/Onboarding sub-namespaces keep
  # URL grouping; everything else is flat.
  resources :orders do
    member do
      post :confirm
      post :start_production, path: "start-production"
      post :mark_ready,       path: "mark-ready"
      post :ship
      post :deliver
      post :mark_paid,        path: "mark-paid"
    end

    # Cancel requires a reason — the dedicated resource gets us a GET for
    # the drawer form and a POST that flows through Orders::Cancel with
    # reason params. Duplicate restores a canceled pedido as a fresh
    # `placed` draft (single POST).
    resource :cancellation, only: %i[new create], controller: "orders/cancellations"
    resource :duplication,  only: %i[create],     controller: "orders/duplications"
  end

  resources :clients do
    collection do
      get :search
    end
  end

  resources :recipes
  resources :ingredients
  resources :delivery_slots, path: "delivery-slots"

  namespace :production do
    get "/",               to: "weekly#show",         as: :weekly
    get "/shopping-list",  to: "shopping_lists#show", as: :shopping_list
  end

  namespace :reports do
    get "/menu",     to: "menu_engineering#show", as: :menu_engineering
    get "/finance",  to: "finance#show",          as: :finance
  end

  namespace :onboarding do
    get    "/",             to: "welcome#show",             as: :root
    get    "/kitchen",      to: "kitchens#new",             as: :kitchen
    post   "/kitchen",      to: "kitchens#create"
    post   "/slug-check",   to: "kitchens#slug_check",      as: :slug_check, defaults: { format: :json }
    get    "/description",  to: "descriptions#edit",        as: :description
    patch  "/description",  to: "descriptions#update"
    get    "/logo",         to: "logos#edit",               as: :logo
    patch  "/logo",         to: "logos#update"
    delete "/logo",         to: "logos#destroy"
    get    "/cover",        to: "covers#edit",              as: :cover
    patch  "/cover",        to: "covers#update"
    delete "/cover",        to: "covers#destroy"
    get    "/done",         to: "completions#show",         as: :done
    post   "/done",         to: "completions#create"

    get  "/recipes/:recipe_id", to: "decomposition#show", as: :decomposition
    post "/recipes/:recipe_id", to: "decomposition#create"
  end

  resource :account, only: %i[show edit update] do
    delete :logo,  to: "accounts#destroy_logo",  as: :logo
    delete :cover, to: "accounts#destroy_cover", as: :cover
  end
  resource :subscription, only: %i[show new create destroy]

  # ---- Webhooks -------------------------------------------------------
  scope :webhooks, module: "webhooks", as: "webhooks" do
    post "/stripe", to: "stripe#create", as: :stripe
  end

  # ---- Public storefronts — ROOT-LEVEL SLUGS --------------------------
  # This block MUST stay last in the file. The constraint rejects any
  # slug in Account::RESERVED_SLUGS so storefront routes can never
  # swallow an app route. Defense in depth — model-level exclusion
  # validation + CI guard + this runtime check.
  scope ":slug",
    constraints: ->(req) { !Account::RESERVED_SLUGS.include?(req.params[:slug]) },
    as: :storefront do
    get "/",     to: "storefronts#show"
    get "/menu", to: "storefronts/menus#show", as: :menu
    resources :orders, only: %i[new create show],
      controller: "storefronts/orders"
  end
end
