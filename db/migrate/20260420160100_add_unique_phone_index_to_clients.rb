class AddUniquePhoneIndexToClients < ActiveRecord::Migration[8.1]
  # Backs `Client.find_or_create_by_phone!` with a race-free uniqueness
  # guarantee. Partial (phone_normalized IS NOT NULL, discarded_at IS NULL)
  # so historical soft-deleted clients never block a fresh record and
  # clients created without a phone don't collide.
  def up
    # Existing seed data + any historical duplicates get soft-deleted
    # before we create the unique index. We keep the earliest record per
    # (account_id, phone_normalized) pair (oldest wins so the operator's
    # first-entered name / notes survive) and discard the rest.
    execute <<~SQL
      UPDATE clients AS c
      SET discarded_at = NOW()
      WHERE discarded_at IS NULL
        AND phone_normalized IS NOT NULL
        AND id NOT IN (
          SELECT MIN(id)
          FROM clients
          WHERE phone_normalized IS NOT NULL
            AND discarded_at IS NULL
          GROUP BY account_id, phone_normalized
        );
    SQL

    # Drop the non-unique legacy index so we don't keep two indexes on the
    # same columns.
    remove_index :clients,
      column: [ :account_id, :phone_normalized ],
      name: :index_clients_on_account_id_and_phone_normalized

    add_index :clients,
      [ :account_id, :phone_normalized ],
      unique: true,
      where: "phone_normalized IS NOT NULL AND discarded_at IS NULL",
      name: "uniq_clients_account_phone_active"
  end

  def down
    remove_index :clients, name: "uniq_clients_account_phone_active"
    add_index :clients,
      [ :account_id, :phone_normalized ],
      name: :index_clients_on_account_id_and_phone_normalized
  end
end
