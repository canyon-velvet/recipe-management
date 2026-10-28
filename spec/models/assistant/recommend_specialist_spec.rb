require "rails_helper"

RSpec.describe Assistant::RecommendSpecialist do
  let(:user) { create(:user) }
  let(:specialist) { described_class.new(user) }

  it "runs on Sonnet at medium effort, with fallbacks, and the recipe tools" do
    expect(specialist.request).to include(model: "claude-sonnet-5-5", output_config: { effort: :medium },
                                          betas: [ "server-side-fallback-2026-07-01" ], fallbacks: :default)
    expect(specialist.request[:tools].pluck(:name)).to eq %w[search_recipes get_recipe show_recipes suggest_preference]
  end

  it "tells Claude the user's preferences, the tags and their ingredients" do
    create(:tag, key: "spicy", kind: "flavor")
    create(:ingredient, user: user, name: "Tofu")
    create(:preference, user: user, category: "avoid", value: "peanut")
    create(:preference, user: user, category: "household", value: "2 adults")

    expect(specialist.system_prompt).to include(
      "- avoid: peanut\n- household: 2 adults", "spicy: Spicy", "Ingredients in the user's recipes: Tofu"
    )
    expect(described_class.new(create(:user)).system_prompt).to include("(none yet)")
  end

  it "lists the user's own tags with the built-in ones, never another user's" do
    korean = user.tags.create!(name: "Korean")
    create(:user).tags.create!(name: "Thai")

    expect(specialist.system_prompt).to include("#{korean.key}: Korean")
    expect(specialist.system_prompt).not_to include("Thai")
  end

  it "ends with the language rule, after the user's data, falling back to the app's language" do
    create(:ingredient, user: user, name: "生抽")

    expect(specialist.system_prompt)
      .to include("生抽\n\nWrite your reply in the language of the user's latest message")
    expect(specialist.system_prompt.strip).to end_with("use English, the app's language.")
    I18n.with_locale(:"zh-CN") { expect(specialist.system_prompt).to include("use 中文, the app's language.") }
  end

  it "shows the recipes its show_recipes tool picked from what its other tools found" do
    recipe = create(:recipe, user: user)

    specialist.tool("search_recipes").call({})
    specialist.tool("show_recipes").call({ recipes: [ { id: recipe.id, why: "Quick." } ] })

    expect(specialist.shown_cards).to eq(recipe.id => "Quick.")
  end
end
