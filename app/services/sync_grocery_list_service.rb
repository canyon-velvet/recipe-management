class SyncGroceryListService
  def initialize(meal_plan)
    @meal_plan = meal_plan
    @grocery_list = meal_plan.grocery_list
  end

  # Under the list's lock, so two syncs at once (ticking two recipes quickly) don't both add the same item
  def call
    @grocery_list.with_lock { sync }
  end

  private

  def sync
    # Count checked recipe occurrences: { recipe_id => count }
    recipe_counts = MealSlotRecipe.in_meal_plan(@meal_plan).for_grocery_list.group(:recipe_id).count

    # Sum occurrence counts per ingredient
    ingredient_counts = {}
    recipe_counts.each do |recipe_id, count|
      RecipeIngredient.where(recipe_id: recipe_id).pluck(:ingredient_id).each do |ing_id|
        ingredient_counts[ing_id] = (ingredient_counts[ing_id] || 0) + count
      end
    end

    # Sync grocery_list_items
    existing = @grocery_list.grocery_list_items.index_by(&:ingredient_id)

    # Remove items no longer needed
    stale_ids = existing.keys - ingredient_counts.keys
    @grocery_list.grocery_list_items.where(ingredient_id: stale_ids).delete_all if stale_ids.any?

    # Add or update items (preserve in_pantry state)
    ingredient_counts.each do |ing_id, count|
      if (item = existing[ing_id])
        item.update!(occurrence_count: count) if item.occurrence_count != count
      else
        @grocery_list.grocery_list_items.create!(ingredient_id: ing_id, occurrence_count: count)
      end
    end
  end
end
