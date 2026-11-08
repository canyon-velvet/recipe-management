# Each user's Light / Dark / Auto choice from the account menu; Auto follows the phone's or computer's own setting
class AddAppearanceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :appearance, :string, null: false, default: "auto"
    add_check_constraint :users, "appearance IN ('auto', 'light', 'dark')", name: "users_appearance"
  end
end
