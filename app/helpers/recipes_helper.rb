module RecipesHelper
  # The recipe's known servings and times for the recipe page, as [label, value] pairs,
  # e.g. [["Servings", "4"], ["Prep", "15 min"], ["Total", "1 hr 15 min"]].
  def recipe_facts(recipe)
    facts = []
    facts << [ t("recipes.facts.servings"), t("recipes.facts.servings_value", count: recipe.servings) ] if recipe.servings
    { prep: recipe.prep_minutes, cook: recipe.cook_minutes, total: recipe.total_minutes }.each do |key, minutes|
      facts << [ t("recipes.facts.#{key}"), duration_label(minutes) ] if minutes
    end
    facts
  end

  # The description as plain text for a card (it's markdown), or else where the recipe is from. Unescaped, so the view
  # escapes it once: "Salt & pepper", not "Salt &amp; pepper".
  def recipe_summary(recipe)
    CGI.unescapeHTML(strip_tags(render_markdown(recipe.description))).squish.presence || recipe.source.name
  end

  # 45 → "45 min", 75 → "1 hr 15 min", 120 → "2 hr"
  def duration_label(minutes)
    hours, rest = minutes.divmod(60)
    parts = []
    parts << t("recipes.facts.hours", count: hours) if hours.positive?
    parts << t("recipes.facts.minutes", count: rest) if rest.positive?
    parts.join(" ")
  end
end
