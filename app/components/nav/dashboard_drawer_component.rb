module Nav
  # Mobile dashboard navigation drawer — the slide-in left-edge variant
  # of DashboardSidebarComponent for screens under lg. Rendered at body
  # level (see panel.html.erb) so the backdrop + panel escape the sticky,
  # blurred top-bar's stacking context — backdrop-filter creates a
  # containing block that would trap position:fixed descendants.
  #
  # The Stimulus wrapper has `class: "contents"` so the element itself
  # is transparent in the DOM; only the backdrop and the panel occupy
  # space, both position:fixed.
  #
  # Triggers ("click->drawer#open") can live anywhere inside the
  # controller's DOM scope — the top-bar hamburger is the primary one.
  class DashboardDrawerComponent < ApplicationComponent
    option :current_user
    option :current_account, optional: true
    option :current_path,    optional: true
  end
end
