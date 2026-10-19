# A recipe shared by link (/r/<token>) has a token; stopping sharing clears it, so the link stops working.
class AddShareTokenToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :share_token, :string
    add_index :recipes, :share_token, unique: true
  end
end
