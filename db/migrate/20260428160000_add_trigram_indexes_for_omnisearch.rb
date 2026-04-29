class AddTrigramIndexesForOmnisearch < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Clients — name, phone, email, rfc
    add_index :clients, :first_name, using: :gin, opclass: :gin_trgm_ops,
              name: "idx_clients_first_name_trgm", algorithm: :concurrently
    add_index :clients, :last_name, using: :gin, opclass: :gin_trgm_ops,
              name: "idx_clients_last_name_trgm", algorithm: :concurrently
    add_index :clients, :phone_normalized, using: :gin, opclass: :gin_trgm_ops,
              name: "idx_clients_phone_trgm", algorithm: :concurrently
    add_index :clients, :email, using: :gin, opclass: :gin_trgm_ops,
              name: "idx_clients_email_trgm", algorithm: :concurrently

    # Recipes — name
    add_index :recipes, :name, using: :gin, opclass: :gin_trgm_ops,
              name: "idx_recipes_name_trgm", algorithm: :concurrently

    # Ingredients — name
    add_index :ingredients, :name, using: :gin, opclass: :gin_trgm_ops,
              name: "idx_ingredients_name_trgm", algorithm: :concurrently
  end
end
