class RenameProductionRunsToBatches < ActiveRecord::Migration[8.1]
  def up
    rename_table :production_runs, :batches
    rename_table :run_consumptions, :batch_consumptions

    rename_column :batch_consumptions, :production_run_id, :batch_id
    rename_column :order_items, :consumed_run_id, :consumed_batch_id

    # Rebuild renamed indexes (Rails won't auto-rename them).
    if index_name_exists?(:batches, "idx_production_runs_account_window")
      rename_index :batches, "idx_production_runs_account_window", "idx_batches_account_window"
    end
    if index_name_exists?(:batch_consumptions, "idx_run_consumptions_consumable")
      rename_index :batch_consumptions, "idx_run_consumptions_consumable", "idx_batch_consumptions_consumable"
    end

    # StockMovement#source is polymorphic — rewrite the recorded class name.
    execute "UPDATE stock_movements SET source_type = 'Batch' WHERE source_type = 'ProductionRun'"

    # Settings JSONB — rename `default_run_window_days` →
    # `default_batch_window_days` in every account.settings.inventory_settings.
    execute <<~SQL
      UPDATE accounts
      SET settings = jsonb_set(
        settings #- '{inventory_settings,default_run_window_days}',
        '{inventory_settings,default_batch_window_days}',
        settings#>'{inventory_settings,default_run_window_days}'
      )
      WHERE settings#>'{inventory_settings,default_run_window_days}' IS NOT NULL
    SQL
  end

  def down
    rename_table :batches, :production_runs
    rename_table :batch_consumptions, :run_consumptions

    rename_column :run_consumptions, :batch_id, :production_run_id
    rename_column :order_items, :consumed_batch_id, :consumed_run_id

    if index_name_exists?(:production_runs, "idx_batches_account_window")
      rename_index :production_runs, "idx_batches_account_window", "idx_production_runs_account_window"
    end
    if index_name_exists?(:run_consumptions, "idx_batch_consumptions_consumable")
      rename_index :run_consumptions, "idx_batch_consumptions_consumable", "idx_run_consumptions_consumable"
    end

    execute "UPDATE stock_movements SET source_type = 'ProductionRun' WHERE source_type = 'Batch'"

    execute <<~SQL
      UPDATE accounts
      SET settings = jsonb_set(
        settings #- '{inventory_settings,default_batch_window_days}',
        '{inventory_settings,default_run_window_days}',
        settings#>'{inventory_settings,default_batch_window_days}'
      )
      WHERE settings#>'{inventory_settings,default_batch_window_days}' IS NOT NULL
    SQL
  end
end
