class AugmentUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string   :first_name
      t.string   :last_name
      t.string   :phone
      t.string   :phone_normalized
      t.datetime :discarded_at, index: true
    end
  end
end
