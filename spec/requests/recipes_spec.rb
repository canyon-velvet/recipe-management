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

  it "names each card's ⋮ menu button for screen readers" do
    create(:recipe, user: user)

    get recipes_path

    button = Nokogiri::HTML(response.body).at_css(".recipe-card [data-controller=dropdown] > button")
    expect(button.attributes.transform_values(&:value)).to include(
      "type" => "button", "aria-label" => "More actions", "aria-haspopup" => "true", "aria-expanded" => "false"
    )
  end

  describe "another user's source or ingredient in the form" do
    let(:other_user) { create(:user) }
    let(:their_source) { create(:source, user: other_user, name: "Their secret source") }
    let(:their_ingredient) { create(:ingredient, user: other_user, name: "Their secret ingredient") }

    it "is not found when creating a recipe" do
      post recipes_path, params: { recipe: {
        name: "Apple cake", source_id: their_source.id,
        recipe_ingredients_attributes: { "0" => { ingredient_id: their_ingredient.id } },
        steps_attributes: { "0" => { body: "Bake it.", position: "1" } }
      } }

      # Not the form, which would show their names (production shows the plain 404 page)
      expect(response).to have_http_status(:not_found)
      expect(user.recipes).to be_empty
    end

    it "is not found when editing a recipe (in either form of the rows)" do
      recipe = create(:recipe, user: user)

      patch recipe_path(recipe), params: { recipe: { source_id: their_source.id } }
      expect(response).to have_http_status(:not_found)

      patch recipe_path(recipe), params: { recipe: { recipe_ingredients_attributes: [ { ingredient_id: their_ingredient.id } ] } }
      expect(response).to have_http_status(:not_found)
      expect(recipe.reload.ingredients).to be_empty
    end
  end

  describe "a recipe planned for the grocery list" do
    let(:egg) { create(:ingredient, user: user, name: "Egg") }
    let(:milk) { create(:ingredient, user: user, name: "Milk") }
    let(:omelette) do
      create(:recipe, user: user, name: "Omelette").tap do |recipe|
        recipe.recipe_ingredients.create!([ { ingredient: egg }, { ingredient: milk } ])
      end
    end
    let(:plan) { user.meal_plans.create!(start_date: Date.new(2026, 10, 19), end_date: Date.new(2026, 10, 25)) }

    def on_the_list = plan.grocery_list.grocery_list_items.reload.map { |item| item.ingredient.name }.sort

    before do
      plan.meal_slots.find_by!(day_of_week: "monday", meal_type: "breakfast").meal_slot_recipes
          .create!(recipe: omelette, add_to_grocery_list: true)
      SyncGroceryListService.new(plan).call
    end

    it "keeps the list in step when the recipe's ingredients change" do
      milk_row = omelette.recipe_ingredients.find_by!(ingredient: milk)

      patch recipe_path(omelette), params: { recipe: {
        recipe_ingredients_attributes: { "0" => { id: milk_row.id, _destroy: "1" } }
      } }

      expect(response).to redirect_to(recipe_path(omelette))
      expect(on_the_list).to eq [ "Egg" ]
    end

    it "takes the recipe's ingredients off the list when it's deleted" do
      expect(on_the_list).to eq [ "Egg", "Milk" ]

      delete recipe_path(omelette)

      expect(on_the_list).to be_empty
    end
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
