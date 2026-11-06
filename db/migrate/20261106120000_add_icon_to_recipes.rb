# A recipe's own icon, chosen in its form, instead of one of its tags' emoji. Each recipe starts with the emoji it
# showed until now, so no card changes: of its tags with an emoji (its own, else the built-in one), in their order,
# the one its id picks (Recipe#card_icon, removed with this). Without one it shows the placeholder.
class AddIconToRecipes < ActiveRecord::Migration[8.1]
  # Tag::ICONS as it is now: the built-in tags' emoji, which are to go
  BUILT_IN_ICONS = {
    "breakfast" => "🥞", "lunch" => "🍱", "dinner" => "🍛", "snack" => "🍪", "dessert" => "🍰",
    "appetizer" => "🍢", "soup" => "🍲", "salad" => "🥗", "drink" => "🧋",
    "chinese" => "🥟", "italian" => "🍝", "japanese" => "🍣", "mexican" => "🌮", "american" => "🍔",
    "vegetarian" => "🥦", "vegan" => "🥑", "gluten_free" => "🍚",
    "spicy" => "🌶️",
    "quick" => "🍳", "kid_friendly" => "🧁", "make_ahead" => "🥫"
  }.freeze

  def up
    add_column :recipes, :icon, :string, limit: 10
    backfill_icons
  end

  def down
    remove_column :recipes, :icon
  end

  # Each recipe's tags in their order (Tag.ordered: position, then id), keeping those with an emoji
  def backfill_icons
    rows = select_rows(<<~SQL)
      SELECT recipe_tags.recipe_id, tags.key, tags.emoji
      FROM recipe_tags JOIN tags ON tags.id = recipe_tags.tag_id
      ORDER BY recipe_tags.recipe_id, tags.position, tags.id
    SQL
    rows.group_by(&:first).each do |recipe_id, tags|
      icons = tags.filter_map { |_, key, emoji| emoji || BUILT_IN_ICONS[key] }
      next if icons.empty?

      execute("UPDATE recipes SET icon = #{quote(icons[recipe_id.to_i % icons.size])} WHERE id = #{recipe_id.to_i}")
    end
  end
end
