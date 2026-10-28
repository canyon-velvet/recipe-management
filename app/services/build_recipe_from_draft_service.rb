# Turns a Draft into an unsaved Recipe for the review form. The source and ingredients are matched to the
# user's own by name; ones the user doesn't have yet are left as new names, created only when the recipe saves.
# Draft data comes from an importer, so anything off the documented shape is skipped rather than trusted.
class BuildRecipeFromDraftService
  def initialize(draft)
    @draft = draft
    @user = draft.user
    @data = draft.data
  end

  def call
    recipe = @user.recipes.build(name: text(@data["name"]), description: description_with_tips,
                                 source_url: @draft.source_url, **counts)
    assign_source(recipe)
    ingredient_rows.each { |attributes| recipe.recipe_ingredients.build(attributes) }
    list("steps").map { text(_1) }.compact_blank.each.with_index(1) { |body, i| recipe.steps.build(body: body, position: i) }
    recipe.tags = Tag.visible_to(@user).where(key: list("tags").map { text(_1) })
    recipe
  end

  private

  def assign_source(recipe)
    name = text(@data["source_name"])
    return if name.empty?

    recipe.source = @user.sources.named(name).first
    recipe.new_source_name = name unless recipe.source
  end

  # One row per ingredient name; a name repeated in the draft keeps its first quantity.
  def ingredient_rows
    items = list("ingredients").select { _1.is_a?(Hash) && text(_1["name"]).present? }.uniq { text(_1["name"]).downcase }
    existing = existing_ingredients(items.map { text(_1["name"]) })

    items.map do |item|
      name = text(item["name"])
      row = { quantity: text(item["quantity"]), unit: text(item["unit"]) }
      ingredient = existing[name.downcase]
      ingredient ? row.merge(ingredient: ingredient) : row.merge(new_ingredient_name: name, new_aisle_id: aisle_id_for(item))
    end
  end

  # The user's ingredients with any of these names, in one query, keyed by lowercase name.
  def existing_ingredients(names)
    return {} if names.empty?

    @user.ingredients.where("lower(name) IN (?)", names.map(&:downcase)).index_by { _1.name.downcase }
  end

  # The importer suggests one of the user's aisles; anything else falls back to Other.
  def aisle_id_for(item)
    @aisle_ids ||= @user.aisles.pluck(:id, :key)
    @aisle_ids.find { |id, _| id.to_s == item["aisle_id"].to_s }&.first || @aisle_ids.find { |_, key| key == "other" }&.first
  end

  # The source's tips go at the end of the description, under a heading in the reviewer's language.
  def description_with_tips
    description = text(@data["description"])
    # One line each, so a tip can't break out of the list (a blank line would end it).
    tips = list("tips").map { text(_1).squish }.compact_blank
    return description if tips.empty?

    section = "**#{I18n.t("recipes.tips_heading")}**\n\n#{tips.map { "- #{_1}" }.join("\n")}"
    [ description.presence, section ].compact.join("\n\n")
  end

  # Servings and times, kept only when they're whole numbers the recipe can save.
  def counts
    Recipe::COUNT_LIMITS.to_h { |key, _| [ key, @data[key.to_s] ] }
                        .select { |key, value| value.is_a?(Integer) && value.between?(1, Recipe::COUNT_LIMITS[key]) }
  end

  def list(key) = @data[key].is_a?(Array) ? @data[key] : []

  def text(value) = value.is_a?(String) || value.is_a?(Numeric) ? value.to_s.strip : ""
end
