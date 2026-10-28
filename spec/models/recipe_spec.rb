require "rails_helper"

RSpec.describe Recipe do
  describe "#avoided_items" do
    it "is the avoid list's items that its ingredients contain, ignoring case" do
      recipe = create(:recipe)
      [ "Peanut butter", "花生油", "Rice" ].each do |name|
        recipe.recipe_ingredients.create!(ingredient: create(:ingredient, user: recipe.user, name: name))
      end

      expect(recipe.reload.avoided_items([ "PEANUT", "花生", "shrimp" ])).to eq [ "PEANUT", "花生" ]
      expect(recipe.avoided_items([])).to eq []
    end
  end

  describe "servings and times" do
    it "fills a blank total from prep and cook time" do
      recipe = create(:recipe, prep_minutes: 15, cook_minutes: 30)

      expect(recipe.total_minutes).to eq 45
    end

    it "keeps a total the source gave" do
      recipe = create(:recipe, prep_minutes: 15, cook_minutes: 30, total_minutes: 60)

      expect(recipe.total_minutes).to eq 60
    end

    it "doesn't fill the total when the save fails, so later changes still add up" do
      recipe = build(:recipe, name: "", prep_minutes: 15, cook_minutes: 30)

      expect(recipe.save).to be false
      expect(recipe.total_minutes).to be_nil
    end

    it "leaves the total blank when prep and cook add up to more than the limit" do
      recipe = create(:recipe, prep_minutes: 10_000, cook_minutes: 200)

      expect(recipe.total_minutes).to be_nil
    end

    it "leaves the total blank when prep or cook time is unknown" do
      recipe = create(:recipe, prep_minutes: 15)

      expect(recipe.total_minutes).to be_nil
    end

    it "allows them all to be blank" do
      expect(build(:recipe)).to be_valid
    end

    it "rejects zero, negative, fractional and too-large values" do
      recipe = build(:recipe, servings: 0, prep_minutes: -5, cook_minutes: "1.5", total_minutes: 99_999)

      expect(recipe).not_to be_valid
      expect(recipe.errors.attribute_names).to include(:servings, :prep_minutes, :cook_minutes, :total_minutes)
    end
  end

  describe ".tagged_any_in_each_kind" do
    it "keeps the recipes with any of the picked tags in each kind picked from" do
      chinese = create(:tag, key: "chinese", kind: "cuisine")
      italian = create(:tag, key: "italian", kind: "cuisine")
      breakfast = create(:tag, key: "breakfast", kind: "meal")
      lunch = create(:tag, key: "lunch", kind: "meal")
      congee = create(:recipe, name: "Congee", tags: [ chinese, breakfast ])
      noodles = create(:recipe, name: "Noodles", tags: [ chinese, lunch ])
      pasta = create(:recipe, name: "Pasta", tags: [ italian, lunch ])
      dumplings = create(:recipe, name: "Dumplings", tags: [ chinese ])

      expect(Recipe.tagged_any_in_each_kind([])).to contain_exactly(congee, noodles, pasta, dumplings)
      expect(Recipe.tagged_any_in_each_kind([ breakfast, lunch ])).to contain_exactly(congee, noodles, pasta)
      expect(Recipe.tagged_any_in_each_kind([ breakfast, lunch, chinese ])).to contain_exactly(congee, noodles)
      expect(Recipe.tagged_any_in_each_kind([ lunch, chinese, italian ])).to contain_exactly(noodles, pasta)
    end
  end

  describe "#description_and_tips" do
    it "splits off the tips under a bold Tips line, in either language" do
      english = build(:recipe, description: "Silky tofu.\n\n**Tips**\n\n- Cut gently.")
      chinese = build(:recipe, description: "嫩豆腐。\n\n**小贴士**\n\n- 轻轻切。")

      expect(english.description_and_tips).to eq [ "Silky tofu.", "- Cut gently." ]
      expect(chinese.description_and_tips).to eq [ "嫩豆腐。", "- 轻轻切。" ]
    end

    it "gives nil for a part that isn't there" do
      expect(build(:recipe, description: "Just a description.").description_and_tips).to eq [ "Just a description.", nil ]
      expect(build(:recipe, description: "**Tips**\n\n- Only tips.").description_and_tips).to eq [ nil, "- Only tips." ]
      expect(build(:recipe, description: nil).description_and_tips).to eq [ nil, nil ]
    end

    it "splits text whose line ends are \\r\\n, as a plain form post sends them" do
      recipe = build(:recipe, description: "Silky tofu.\r\n\r\n**Tips**\r\n\r\n- Cut gently.")

      expect(recipe.description_and_tips).to eq [ "Silky tofu.", "- Cut gently." ]
    end

    it "gathers the tips under a second Tips line too" do
      recipe = build(:recipe, description: "A.\n\n**Tips**\n\n- One.\n\n**Tips**\n\n- Two.")

      expect(recipe.description_and_tips).to eq [ "A.", "- One.\n\n- Two." ]
    end

    it "leaves bold words inside a paragraph alone" do
      recipe = build(:recipe, description: "Some **Tips** inside a sentence.")

      expect(recipe.description_and_tips).to eq [ "Some **Tips** inside a sentence.", nil ]
    end
  end

  it "takes a source, and its ingredients an aisle, only of the same user" do
    user, other_user = create_list(:user, 2)

    expect(build(:recipe, user: user, source: create(:source, user: other_user)).tap(&:validate).errors.attribute_names).to include(:source)
    expect(build(:recipe, user: user, source: create(:source, user: user))).to be_valid
    expect(build(:ingredient, user: user, aisle: other_user.aisles.first).tap(&:validate).errors.attribute_names).to include(:aisle)
    expect(build(:ingredient, user: user, aisle: user.aisles.first)).to be_valid
  end

  it "takes the built-in tags and the user's own, but not another user's" do
    user, other_user = create_list(:user, 2)
    built_in = create(:tag, key: "dinner", kind: "meal")

    expect(build(:recipe, user: user, tags: [ built_in, user.tags.create!(name: "Korean") ])).to be_valid
    expect(build(:recipe, user: user, tags: [ other_user.tags.create!(name: "Thai") ])
             .tap(&:validate).errors.attribute_names).to include(:tags)
  end
end
