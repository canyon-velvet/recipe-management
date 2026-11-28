# The order of a recipe's ingredients, which the form lets the user change. Existing rows keep the order they were
# added in.
class AddPositionToRecipeIngredients < ActiveRecord::Migration[8.1]
  def change
    add_column :recipe_ingredients, :position, :integer
    up_only do
      execute <<~SQL
        UPDATE recipe_ingredients SET position = numbered.position
        FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY recipe_id ORDER BY id) AS position
              FROM recipe_ingredients) numbered
        WHERE recipe_ingredients.id = numbered.id
      SQL
    end
    change_column_null :recipe_ingredients, :position, false
    add_index :recipe_ingredients, [ :recipe_id, :position ]
  end
end
