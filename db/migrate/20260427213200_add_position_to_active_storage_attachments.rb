class AddPositionToActiveStorageAttachments < ActiveRecord::Migration[8.1]
  # Multi-photo recipes — Active Storage attachments need a stable
  # order so the operator's drag-reordered photos render the same
  # way on every paint. Adding `position` directly to
  # `active_storage_attachments` is the documented Rails-native
  # pattern; nullable for backfill safety, and the partial index
  # only covers the rows that actually use it (Recipe + future
  # multi-attachment models).
  def change
    add_column :active_storage_attachments, :position, :integer

    add_index  :active_storage_attachments,
               %i[record_type record_id name position],
               where: "position IS NOT NULL",
               name:  "idx_asa_record_position"
  end
end
