require "rails_helper"

RSpec.describe RecipesHelper, type: :helper do
  describe "#recipe_facts" do
    it "lists only what's known" do
      recipe = build(:recipe, servings: 4, cook_minutes: 75)

      expect(helper.recipe_facts(recipe)).to eq [ [ "Servings", "4" ], [ "Cook", "1 hr 15 min" ] ]
    end

    it "is empty when nothing is known" do
      expect(helper.recipe_facts(build(:recipe))).to eq []
    end

    it "speaks the current language" do
      recipe = build(:recipe, servings: 2, total_minutes: 120)

      I18n.with_locale(:"zh-CN") do
        expect(helper.recipe_facts(recipe)).to eq [ [ "份量", "2 人份" ], [ "总时间", "2 小时" ] ]
      end
    end
  end

  describe "#recipe_summary" do
    it "gives the description as one line of plain text" do
      recipe = build(:recipe, description: "**Salt** & pepper,\n\nthen <b>more</b>.")

      expect(helper.recipe_summary(recipe)).to eq "Salt & pepper, then more."
    end

    it "falls back to where the recipe is from" do
      recipe = build(:recipe, description: "")

      expect(helper.recipe_summary(recipe)).to eq recipe.source.name
    end
  end
end
