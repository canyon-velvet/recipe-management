require "rails_helper"

RSpec.describe "Recipes", type: :request do
  let(:user) { create(:user) }

  before { post login_path, params: { username: user.username, password: "password" } }

  it "saves servings and times from the form, filling the total from prep and cook" do
    post recipes_path, params: { recipe: {
      name: "Apple cake", source_id: create(:source, user: user).id,
      servings: "4", prep_minutes: "15", cook_minutes: "30", total_minutes: "",
      steps_attributes: { "0" => { body: "Bake it.", position: "1" } }
    } }

    recipe = user.recipes.sole
    expect([ recipe.servings, recipe.prep_minutes, recipe.cook_minutes, recipe.total_minutes ]).to eq [ 4, 15, 30, 45 ]
    follow_redirect!
    facts = Nokogiri::HTML(response.body).css(".recipe-facts > div").map { |fact| fact.css("dt, dd").map(&:text) }
    expect(facts).to eq [ [ "Servings", "4" ], [ "Prep", "15 min" ], [ "Cook", "30 min" ], [ "Total", "45 min" ] ]
  end

  it "shows a validation error, not a crash, for a number too large to save" do
    post recipes_path, params: { recipe: {
      name: "Apple cake", source_id: create(:source, user: user).id, prep_minutes: "9999999999",
      steps_attributes: { "0" => { body: "Bake it.", position: "1" } }
    } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.recipes).to be_empty
  end

  it "lays the form out as the content on the left and Save with the details in a sidebar" do
    recipe = create(:recipe, user: user)

    get edit_recipe_path(recipe)

    page = Nokogiri::HTML(response.body)
    expect(page.css(".recipe-form-main .recipe-form-card-title").map(&:text)).to eq %w[Ingredients Method]
    expect(page.at_css(".recipe-form-main #recipe_name")).to be_present
    details = page.at_css(".recipe-form-details")
    expect(details.at_css("input[type=submit]")["value"]).to eq "Update recipe"
    expect(details.css("label").map { _1.text.squish }).to include("Tags", "Servings", "Source", "Recipe link")
  end

  describe "the recipe page" do
    let(:source) { create(:source, user: user, name: "Yummy Toddler Food") }

    def page_for(recipe)
      get recipe_path(recipe)
      Nokogiri::HTML(response.body)
    end

    it "shows the description up top, then Ingredients, Method and the tips last" do
      recipe = build(:recipe, user: user, source: source, description: "Silky tofu.\n\n**Tips**\n\n- Cut gently.")
      recipe.recipe_ingredients.build(ingredient: create(:ingredient, user: user, name: "Tofu"), quantity: "400", unit: "g")
      recipe.save!

      page = page_for(recipe)

      expect(page.css(".recipe-description").text.squish).to eq "Silky tofu."
      expect(page.css(".recipe-section-heading").map(&:text)).to eq %w[Ingredients Method Tips]
      expect(page.css(".recipe-tips").text.squish).to eq "Cut gently."
      expect(page.css(".recipe-heading-actions a").map { _1.text.squish }).to eq [ "✎ Edit", "Delete" ]
    end

    it "leaves out the ingredients and tips sections when there are none" do
      page = page_for(create(:recipe, user: user, source: source, description: "Silky tofu."))

      expect(page.css(".recipe-section-heading").map(&:text)).to eq %w[Method]
    end

    it "links where it's from to the original, only when there's a link" do
      linked = create(:recipe, user: user, source: source, source_url: "https://example.com/tofu")
      unlinked = create(:recipe, user: user, source: source)

      expect(page_for(linked).at_css(".recipe-source a")["href"]).to eq "https://example.com/tofu"
      expect(page_for(linked).at_css(".recipe-source").text.squish).to eq "From Yummy Toddler Food ↗"
      expect(page_for(unlinked).at_css(".recipe-source a")).to be_nil
      expect(page_for(unlinked).at_css(".recipe-source").text.squish).to eq "From Yummy Toddler Food"
    end
  end
end
