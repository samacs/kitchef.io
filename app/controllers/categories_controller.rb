class CategoriesController < AuthenticatedController
  # POST /categories
  #
  # Inline creator hit by the Ui::ComboboxComponent when the operator
  # types a new value and presses ↵ Agregar. Returns a Turbo Stream that
  # appends a new <option> to the combobox's datalist AND a JSON payload
  # the Stimulus controller uses to update its state (selected id).
  #
  # The operator never sees a category management page — this inline
  # flow plus the nudge on ingredient/recipe forms is the entire surface.
  def create
    kind = params[:kind].to_s
    unless Category.kinds.key?(kind)
      head :unprocessable_content
      return
    end

    category = Current.account.categories.build(
      kind: kind,
      name: params[:name].to_s.strip
    )

    respond_to do |format|
      if category.save
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            dom_id_for_combobox(kind),
            partial: "categories/option",
            locals: { category: category }
          )
        end
        format.json { render json: serialize(category), status: :created }
      else
        format.turbo_stream { head :unprocessable_content }
        format.json { render json: { errors: category.errors.full_messages }, status: :unprocessable_content }
      end
    end
  end

  # DELETE /categories/:id  — guarded by restrict_with_error.
  def destroy
    category = Current.account.categories.kept.find(params[:id])

    if category.usage_count.positive?
      redirect_back fallback_location: ingredients_path,
        alert: t(".in_use", count: category.usage_count, name: category.name)
    else
      category.discard
      redirect_back fallback_location: ingredients_path, notice: t(".discarded")
    end
  end

  private

  def dom_id_for_combobox(kind)
    "combobox_#{kind}_options"
  end

  def serialize(category)
    { id: category.id, label: category.name, kind: category.kind }
  end
end
