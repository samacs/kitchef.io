class AddRfcToClientsAndSuppliers < ActiveRecord::Migration[8.1]
  # RFC (Registro Federal de Contribuyentes) — Mexican tax ID the operator's
  # contador needs on every fiscal document. Always nullable; operators
  # who aren't invoicing don't collect it.
  #
  # 12 chars for personas morales (companies), 13 for personas físicas.
  # We store the raw normalized string; format is validated in the models.
  def change
    add_column :clients,   :rfc, :string
    add_column :suppliers, :rfc, :string

    add_index :clients,   [ :account_id, :rfc ], where: "rfc IS NOT NULL"
    add_index :suppliers, [ :account_id, :rfc ], where: "rfc IS NOT NULL"
  end
end
