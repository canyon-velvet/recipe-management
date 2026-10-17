# A recipe once per meal, also when it's added twice at once (a double click): drop any copies that got in, keeping
# the first, then let the database refuse them.
class AddUniqueIndexToMealSlotRecipes < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      DELETE FROM meal_slot_recipes copy
      USING meal_slot_recipes original
      WHERE copy.meal_slot_id = original.meal_slot_id AND copy.recipe_id = original.recipe_id AND copy.id > original.id
    SQL
    add_index :meal_slot_recipes, [ :meal_slot_id, :recipe_id ], unique: true
  end

  def down
    remove_index :meal_slot_recipes, [ :meal_slot_id, :recipe_id ]
  end
end
