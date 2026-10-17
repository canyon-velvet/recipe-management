# The zone a user's "today" and "this week" follow (tonight's dinner, the current meal plan), picked on Preferences.
class AddTimeZoneToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :time_zone, :string, null: false, default: "Central Time (US & Canada)"
  end
end
