module IconHelper
  # Render a Lucide icon with our default sizing.
  #
  #   icon(:plus)                       # 20x20, currentColor
  #   icon(:check, size: :sm)           # 16x16
  #   icon(:trash, size: :lg, class: "text-err")
  DEFAULT_SIZE_CLASSES = {
    xs: "w-3 h-3",
    sm: "w-4 h-4",
    md: "w-5 h-5",
    lg: "w-6 h-6",
    xl: "w-7 h-7"
  }.freeze

  def icon(name, size: :md, class: nil, **options)
    size_class = DEFAULT_SIZE_CLASSES.fetch(size)
    merged_class = [ size_class, binding.local_variable_get(:class) ].compact.join(" ")
    lucide_icon(name.to_s.tr("_", "-"), class: merged_class, **options)
  end
end
