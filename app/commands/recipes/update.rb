module Recipes
  # Updates an existing recipe with the submitted params. Simple-mode defaults
  # don't reappear here — the operator already picked them at creation time
  # and we don't want to clobber any advanced-mode tweaks a later phase will
  # let her set.
  #
  # Accepts optional `components_attributes` (Phase 7) — nested attributes
  # for the recipe's components (ingredient / sub-recipe rows). The nested
  # payload is pre-filtered by the model's `accepts_nested_attributes_for`
  # so fully blank rows don't reach the DB.
  #
  # Enforces the one cross-field rule the form should honor: a recipe can
  # only be published if it has a photo attached. Attempting to publish a
  # photoless recipe returns a validation error the form re-renders.
  class Update < ApplicationCommand
    option :recipe
    option :params

    def call
      photo_payload = extract_photo_payload!

      recipe.assign_attributes(params.to_h)

      if publishing_without_photo?(photo_payload)
        recipe.errors.add(:is_published, :requires_photo)
        return Result.new(success: false, object: recipe, errors: recipe.errors)
      end

      ActiveRecord::Base.transaction do
        recipe.save!
        apply_photo_payload!(photo_payload)
      end

      success(recipe)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, object: e.record, errors: e.record.errors)
    end

    private

    # Pulls the multi-photo form fields out of params before
    # `assign_attributes` runs — these keys aren't model attributes,
    # they're driven by the photo-grid Stimulus controller.
    #
    # Accepts both the legacy `photos[]` array (single-tile path)
    # and the new `new_photos[]` (multi-tile grid). `remove_photo_ids`
    # is a CSV; `photo_order` is a JSON array of `{kind: "existing"|"pending", id|index}`.
    def extract_photo_payload!
      legacy   = Array(params.delete(:photos))
      new_pics = Array(params.delete(:new_photos))
      remove   = params.delete(:remove_photo_ids).to_s
      order    = params.delete(:photo_order).to_s

      {
        new_files:  (legacy + new_pics).select { |f| f.respond_to?(:size) && f.size.positive? },
        remove_ids: remove.split(",").map(&:to_i).reject(&:zero?),
        order:      parse_order(order)
      }
    end

    def parse_order(raw)
      return [] if raw.blank?
      JSON.parse(raw)
    rescue JSON::ParserError
      []
    end

    def apply_photo_payload!(payload)
      remove_marked_attachments!(payload[:remove_ids])
      new_attachments = attach_new_files!(payload[:new_files])
      apply_positions!(payload[:order], new_attachments)
    end

    def remove_marked_attachments!(ids)
      return if ids.empty?
      recipe.photos.attachments.where(id: ids).find_each(&:purge_later)
    end

    # Returns the freshly created attachments in the order they were
    # provided so the position-application step can map `pending`
    # entries (`{kind: "pending", index: N}`) back to a real id.
    #
    # We create blob + attachment rows explicitly because reading back
    # `recipe.photos.attachments` mid-flight returns the in-memory
    # change array (not an AR relation), which has no `.order`.
    def attach_new_files!(files)
      files.map do |file|
        blob = ActiveStorage::Blob.create_and_upload!(
          io: file.respond_to?(:tempfile) ? file.tempfile : file,
          filename: file.original_filename,
          content_type: file.content_type
        )
        ActiveStorage::Attachment.create!(record: recipe, name: "photos", blob: blob)
      end
    end

    def apply_positions!(order, new_attachments)
      return if order.empty?

      order.each_with_index do |entry, idx|
        attachment_id = case entry["kind"]
        when "existing" then entry["id"].to_i
        when "pending"  then new_attachments[entry["index"].to_i]&.id
        end
        next if attachment_id.nil? || attachment_id.zero?

        ActiveStorage::Attachment.where(id: attachment_id).update_all(position: idx)
      end
    end

    # True when this submission FLIPS the recipe to published but the
    # recipe has neither an already-attached photo nor a new one in
    # this submission. Accounts for photos marked for removal in the
    # same submit so an operator can't slip past by toggling publish
    # while wiping every photo at once.
    def publishing_without_photo?(photo_payload)
      return false unless recipe.is_published?
      return false unless recipe.will_save_change_to_is_published?

      remaining_existing = recipe.photos.attachments.where.not(id: photo_payload[:remove_ids]).count
      remaining_existing.zero? && photo_payload[:new_files].empty?
    end
  end
end
