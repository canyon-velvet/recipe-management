# Invite links an admin hands out: signing up takes one, and each works once until it expires (see Invite).
class CreateInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :invites do |t|
      t.string :token, null: false, index: { unique: true }
      t.references :created_by, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      # Kept as used when that account is deleted
      t.references :used_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :used_at
      t.datetime :expires_at, null: false
      t.string :note
      t.timestamps
    end
  end
end
