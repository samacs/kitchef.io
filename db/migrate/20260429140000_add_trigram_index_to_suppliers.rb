class AddTrigramIndexToSuppliers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :suppliers, :name, using: :gin, opclass: :gin_trgm_ops,
              name: "idx_suppliers_name_trgm", algorithm: :concurrently
  end
end
