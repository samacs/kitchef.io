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
  # Column-header bulk action — lives OUTSIDE `resources :orders` so its
  # `/orders/bulk/:event` pattern can't collide with member routes like
  # `/orders/:id/confirm` (which would otherwise match "bulk" as an :id).
  post "/orders/bulk/:event",
    to: "orders#bulk_transition",
    as: :bulk_transition_orders

  resources :orders do
    member do
      post :confirm
      post :start_production, path: "start-production"
      post :mark_ready,       path: "mark-ready"
      post :ship
      post :deliver
      post :mark_paid,        path: "mark-paid"
      post :unmark_paid,      path: "unmark-paid"
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

  # Phase 9 — proveedores & per-supplier price history. Combobox inline
  # flow on the ingredient form hits #create via JSON; the management
  # surface at /proveedores lives for the "I just opened a new shop"
  # and "bulk-edit contact info" cases.
  resources :suppliers,
    path: "proveedores",
    path_names: { new: "nuevo", edit: "editar" } do
    collection do
      get :search
    end
  end

  # Purchase ledger — the "paper receipt + thumb" surface. The mobile-
  # first new-purchase form lives at /compras/nuevo; index is the
  # chronological list of what's been bought; CSV export feeds the
  # operator's contador.
  resources :purchases,
    path: "compras",
    path_names: { new: "nuevo", edit: "editar" }

  # Phase 10 — fixed costs (renta, gas, plataformas). One row per
  # recurring line item; the finance report prorates them against the
  # window to land on "Utilidad neta".
  resources :fixed_costs,
    path: "costos-fijos",
    path_names: { new: "nuevo", edit: "editar" }

  # Inline creator for the fixed-cost category combobox (same pattern
  # as CategoriesController#create). No management UI in v1 — inline
  # creation + restrict_with_error on destroy is the whole surface.
  resources :fixed_cost_categories, only: %i[create destroy],
    path: "fixed-cost-categories"

  resources :recipes do
    member do
      post :toggle_publish, path: "toggle-publish"
      post :duplicate
      post :restore
    end
    collection do
      get  :archived
      post :publish_all,        path: "publish-all"
      post :rescale_for_margin, path: "rescale-for-margin"
    end
  end
  resources :ingredients do
    # Nested per-ingredient Supplier price rows, controlled from the
    # "Proveedores y precios" panel inside the ingredient edit drawer.
    resources :supplier_prices, only: %i[create update destroy],
      controller: "ingredients/supplier_prices"
  end

  # Inline Agregar flow from the Ui::ComboboxComponent — operator types
  # a new category name in the picker, presses ↵, this endpoint creates
  # the row and returns JSON + a Turbo Stream that updates the datalist.
  # No management UI in v1; the inline creator + the restrict_with_error
  # guard on Category#destroy is the whole surface.
  resources :categories, only: %i[create destroy]

  # One schedule per account — weekly grid + date-specific exceptions.
  # Replaces the Phase 5 /delivery-slots editor and the ordering-hours
  # block formerly on /account/edit; both retired in Phase 6.
  #
  # Schedule settings (order_mode, lead_time_minutes) autosave via PATCH
  # /schedule. Availabilities are managed individually via the nested
  # collection so adds / edits / removes stay idempotent + Turbo-stream
  # friendly — no accepts_nested_attributes fragility.
  resource :schedule, only: %i[show update] do
    resources :availabilities, only: %i[create update destroy],
      controller: "schedules/availabilities"
  end

  # Phase 5: top-level daily focus view. The previous `Production::Weekly`
  # stub is gone — `/production` now lands on the real planner.
  get "/production",               to: "production#show",          as: :production
  get "/production/shopping-list", to: "production#shopping_list", as: :production_shopping_list
  # "Marcar como comprada" drawer + submit — per-ingredient quick-record
  # into today's Purchase for the chosen supplier.
  get  "/production/shopping-list/mark/:ingredient_id/new", to: "production/purchase_marks#new",    as: :new_production_purchase_mark
  post "/production/shopping-list/mark/:ingredient_id",     to: "production/purchase_marks#create", as: :production_purchase_marks
  post "/production/bulk-start-production",
    to: "production#bulk_start_production",
    as: :production_bulk_start_production

  # Phase 13 — batches (lotes) + inventory onboarding. Gated by
  # `account.inventory_enabled?` at the controller layer; the routes
  # exist regardless so flipping the toggle is instant. Mounted at
  # /batches (top-level, decoupled from /production which is the
  # daily-orders focus view from Phase 5).
  get "/batches/onboarding",  to: "batches/onboardings#show",  as: :batches_onboarding
  # Live ingredient-impact preview for the new-batch form. Stimulus
  # debounces form changes and updates this frame's src so the
  # operator sees what she'll consume in real time.
  get "/batches/impact",      to: "batches#impact",             as: :batches_impact
  resources :batches do
    member do
      post :cancel
      post :complete
    end
  end

  # Zero-auth runner view — one signed token per day, resolved server-side
  # back to an account + date. Any tamper or >24h staleness lands on the
  # branded "ruta expirada" page.
  get  "/r/:token",                 to: "runners#show",    as: :runner
  post "/r/:token/orders/:id/deliver", to: "runners#deliver", as: :runner_deliver

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

  resource :account, only: %i[show edit update destroy] do
    delete :logo,  to: "accounts#destroy_logo",  as: :logo
    delete :cover, to: "accounts#destroy_cover", as: :cover
  end
  resource :subscription, only: %i[show new create destroy] do
    # Hint banner dismissals (Phase 14, Slice 1). Posted by the "x"
    # button on `Subscriptions::HintBanner`; writes a per-account
    # `DismissedHint` row so the same banner doesn't reappear on
    # device-switch.
    post "hints/:hint_key/dismiss",
         to:   "subscriptions/hint_dismissals#create",
         as:   :hint_dismissal,
         constraints: { hint_key: %r{[\w:.-]+} }

    # Phase 14, Slice 5 — billing dashboard actions.
    # Plan switching (mensual ↔ anual with proration via Stripe).
    post "plan-switch",
         to: "subscriptions/plan_switches#create",
         as: :plan_switch

    # Cancel save-flow:
    #   GET  /subscription/cancel       → exit-survey form
    #   POST /subscription/cancel       → choose reason → save-offer page
    #   POST /subscription/cancel/save  → accept the matched save offer
    #   POST /subscription/cancel/confirm → hard cancel
    get  "cancel",         to: "subscriptions/cancellations#new",     as: :cancel
    post "cancel",         to: "subscriptions/cancellations#create"
    post "cancel/save",    to: "subscriptions/cancellations#save",    as: :cancel_save
    post "cancel/confirm", to: "subscriptions/cancellations#confirm", as: :cancel_confirm

    # Downgrade to Free without going through the save-flow.
    post "downgrade",
         to: "subscriptions/downgrades#create",
         as: :downgrade

    # Phase 14, Slice 6 — billing history + Stripe Portal entry.
    get  "invoices",
         to: "subscriptions/invoices#index",
         as: :invoices
    post "portal",
         to: "subscriptions/portal_sessions#create",
         as: :portal
  end

  resources :notifications, only: %i[index] do
    member do
      post :mark_read, path: "mark-read"
    end
    collection do
      post :mark_all_read, path: "mark-all-read"
    end
  end

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
    # Dish detail — one recipe per URL. The `recipe_slug` resolves via
    # FriendlyId scoped to the account, so two kitchens can each have a
    # "pozole-rojo" without collision.
    get "/dishes/:recipe_slug",           to: "storefronts/recipes#show",      as: :recipe
    get "/dishes/:recipe_slug/customize", to: "storefronts/recipes#customize", as: :recipe_customize
    resources :orders, only: %i[new create show],
      controller: "storefronts/orders" do
      member do
        # Customer self-confirm is now a POST so it carries the reviewed
        # address + delivery notes. The email CTA lands on the order show
        # page (GET), the customer taps the Confirm button, which fires
        # this POST. Idempotent on replay (AASM guard returns false).
        post :confirm
      end
    end
  end
end
