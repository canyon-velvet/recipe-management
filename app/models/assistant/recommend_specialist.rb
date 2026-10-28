module Assistant
  # The specialist that suggests recipes from the user's own collection, following their preferences.
  class RecommendSpecialist < Agent
    MODEL = "claude-sonnet-5-5"
    NAME = "recommend"
    TITLE = "Recommend"
    # For the router's transfer tool: when to hand over.
    HANDLES = "searches the user's saved recipes and suggests some. Use it when they want recipes from their own " \
              "collection: what to cook tonight, something with eggs, a quick dinner, a dish for guests"

    PROMPT = <<~PROMPT.freeze
      You are the Recommend specialist of the assistant in a home recipe app. You suggest recipes from the user's own
      saved collection, never from anywhere else. If nothing fits, say so and suggest widening the search (another
      tag, fewer filters) or importing a recipe from a link.

      Use search_recipes to find candidates and get_recipe to read one in full, for example to judge from its
      ingredients how spicy it is. Ingredient names are as the user wrote them, in Chinese or English; try both
      languages when one finds nothing. Then call show_recipes with the recipes you recommend and, for each, a short
      why: they appear as cards under your reply, each with its why. Only recommend recipes a tool returned while
      you wrote this reply.

      Follow the user's preferences. Prefer recipes without any of their "avoid" items; the tools list the ones a
      recipe contains under "avoided". If such a recipe is the best or only fit, you may still recommend it, but say
      clearly which avoided item it contains (its card is marked too). The other preferences are soft: lean towards
      their diet and likes, away from dislikes, and suit the household. If the user mentions a lasting fact that
      isn't among their preferences yet ("we're vegetarian", "my son is allergic to peanuts"), call
      suggest_preference so they can save it with a click. It isn't saved until they do, so don't say you'll
      remember it; say they can save it below.

      Above the cards, write a sentence or two that answers the user, without repeating each card's why. Don't
      describe your searches.
    PROMPT

    # The instructions, then what the user has (their preferences, the tags and their ingredients' names), then the
    # language rule.
    def system_prompt
      <<~PROMPT
        #{PROMPT}
        The user's preferences:
        #{preferences_list}

        Tags (key: name):
        #{Tag.visible_to(@user).ordered.map { |tag| "#{tag.key}: #{tag.name}" }.join("\n")}

        Ingredients in the user's recipes: #{@user.ingredients.order(:name).pluck(:name).join(", ")}

        #{language_rule}
      PROMPT
    end

    private

    def build_tools
      [ Tools::SearchRecipes, Tools::GetRecipe, Tools::ShowRecipes, Tools::SuggestPreference ]
        .map { |tool| tool.new(@user, turn) }
    end

    def request_options
      {
        output_config: { effort: :medium },
        # If the model declines, the API retries on a suitable fallback model within the same call.
        betas: [ "server-side-fallback-2026-07-01" ], fallbacks: :default
      }
    end

    def preferences_list
      preferences = @user.preferences.ordered
      return "(none yet)" if preferences.empty?

      preferences.map { |preference| "- #{preference.category}: #{preference.value}" }.join("\n")
    end
  end
end
