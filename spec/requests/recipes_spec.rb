require "rails_helper"

RSpec.describe "Recipes", type: :request do
  let(:user) { create(:user) }

  before { log_in_as user }

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
    expect(details.css("label, legend").map { _1.text.squish }).to include("Tags", "Servings", "Source", "Recipe link")
  end

  it "shows the sidebar's tags without their emoji, counting the user's own recipes" do
    soup = create(:tag, key: "soup", kind: "meal")
    create(:recipe, user: user, tags: [ soup ])
    create(:recipe, tags: [ soup ]) # someone else's

    get recipes_path

    catalog = Nokogiri::HTML(response.body).at_css(".tag-catalog")
    expect(catalog.css("a, label").map { _1.text.squish }).to eq [ "All recipes 1", "Soup 1" ]
    expect(catalog.text).not_to include(soup.icon)
  end

  it "names each row's ⋮ menu button for screen readers" do
    create(:recipe, user: user)

    get recipes_path

    button = Nokogiri::HTML(response.body).at_css(".recipe-row [data-controller=dropdown] > button")
    expect(button.attributes.transform_values(&:value)).to include(
      "type" => "button", "aria-label" => "More actions", "aria-haspopup" => "true", "aria-expanded" => "false"
    )
  end

  it "saves none of an edit that fails, its tags included" do
    recipe = create(:recipe, user: user, name: "Apple cake")
    tag = create(:tag, key: "spicy", kind: "flavor")

    patch recipe_path(recipe), params: { recipe: { name: "", tag_ids: [ "", tag.id ] } }
    expect(response).to have_http_status(:unprocessable_content)

    patch recipe_path(recipe), params: { recipe: { source_id: create(:source).id, tag_ids: [ "", tag.id ] } }
    expect(response).to have_http_status(:not_found)

    expect(recipe.reload.tags).to be_empty
    expect(recipe.name).to eq "Apple cake"
  end

  it "keeps a removed ingredient removed when an edit fails, so saving again doesn't bring it back" do
    recipe = create(:recipe, user: user, name: "Omelette")
    egg_row = recipe.recipe_ingredients.create!(ingredient: create(:ingredient, user: user, name: "Egg"))

    patch recipe_path(recipe), params: { recipe: {
      name: "", recipe_ingredients_attributes: { "0" => { id: egg_row.id, _destroy: "1" } }
    } }

    expect(response).to have_http_status(:unprocessable_content)
    id_field = Nokogiri::HTML(response.body)
      .at_css("input[name^='recipe[recipe_ingredients_attributes]'][name$='[id]'][value='#{egg_row.id}']")
    row = id_field.ancestors("[data-nested-form-row]").first
    expect(row["class"].split).to include("hidden")
    expect(ActiveModel::Type::Boolean.new.cast(row.at_css("input[name$='[_destroy]']")["value"])).to be true
  end

  it "shows a typed new ingredient's aisle as Other when an edit fails, not the first aisle" do
    recipe = create(:recipe, user: user)

    patch recipe_path(recipe), params: { recipe: {
      name: "", recipe_ingredients_attributes: { "0" => { ingredient_id: "", new_ingredient_name: "Saffron" } }
    } }

    expect(response).to have_http_status(:unprocessable_content)
    aisle_select = Nokogiri::HTML(response.body).at_css("select[name$='[new_aisle_id]']")
    expect(aisle_select.at_css("option[selected]").text).to eq "Other"
  end

  it "saves an ingredient removed and added again in the same edit, once" do
    recipe = create(:recipe, user: user)
    egg = create(:ingredient, user: user, name: "Egg")
    egg_row = recipe.recipe_ingredients.create!(ingredient: egg, quantity: "2")

    patch recipe_path(recipe), params: { recipe: { recipe_ingredients_attributes: {
      "0" => { id: egg_row.id, _destroy: "1" }, "1" => { ingredient_id: egg.id, quantity: "3" }
    } } }

    expect(response).to redirect_to(recipe_path(recipe))
    expect(recipe.recipe_ingredients.reload.map { [ _1.ingredient, _1.quantity ] }).to eq [ [ egg, "3" ] ]
  end

  it "still won't list an ingredient twice" do
    recipe = create(:recipe, user: user)
    egg = create(:ingredient, user: user, name: "Egg")
    recipe.recipe_ingredients.create!(ingredient: egg)

    patch recipe_path(recipe), params: { recipe: { recipe_ingredients_attributes: { "1" => { ingredient_id: egg.id } } } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(recipe.recipe_ingredients.reload.size).to eq 1
  end

  it "refuses, rather than fails on, a row taking the ingredient another row is changing from" do
    recipe = create(:recipe, user: user)
    egg, milk = %w[Egg Milk].map { |name| create(:ingredient, user: user, name: name) }
    egg_row, milk_row = [ egg, milk ].map { |ingredient| recipe.recipe_ingredients.create!(ingredient: ingredient) }

    # The rows save one by one, so Egg's row would become Milk while Milk's row still is
    patch recipe_path(recipe), params: { recipe: { recipe_ingredients_attributes: {
      "0" => { id: egg_row.id, ingredient_id: milk.id },
      "1" => { id: milk_row.id, ingredient_id: create(:ingredient, user: user, name: "Flour").id }
    } } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(recipe.recipe_ingredients.reload.map(&:ingredient)).to contain_exactly(egg, milk)
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
      expect(page.css(".recipe-heading-actions a").map { _1.text.squish }).to eq [ "Share", "✎ Edit", "Delete" ]
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

  describe "searching" do
    let(:breakfast) { create(:tag, key: "breakfast", kind: "meal") }

    def with_ingredients(name, *ingredients, tags: [])
      create(:recipe, user: user, name: name, tags: tags).tap do |recipe|
        ingredients.each { |ingredient| recipe.recipe_ingredients.create!(ingredient: create(:ingredient, user: user, name: ingredient)) }
      end
    end

    def listed = Nokogiri::HTML(response.body).css(".recipe-row-link").map { _1["aria-label"] }

    before do
      with_ingredients("Pancakes", "eggs", "flour", tags: [ breakfast ])
      with_ingredients("Egg fried rice", "rice")
      with_ingredients("Fried egg sandwich", "egg yolk", "bread")
      with_ingredients("Tomato soup", "tomatoes")
      someone_else = create(:user)
      create(:recipe, user: someone_else, name: "Their egg tart").recipe_ingredients
        .create!(ingredient: create(:ingredient, user: someone_else, name: "eggs"))
    end

    it "finds a recipe in the list by its name or one of its ingredients, among the user's own" do
      get recipes_path(q: "egg")

      expect(listed).to contain_exactly("Pancakes", "Egg fried rice", "Fried egg sandwich")
    end

    it "finds a recipe in the list by its source, among the user's own" do
      create(:recipe, user: user, name: "Braised pork", source: create(:source, user: user, name: "Mom's notebook"))
      someone_else = create(:user)
      create(:recipe, user: someone_else, name: "Their stew", source: create(:source, user: someone_else, name: "Mom"))

      get recipes_path(q: "mom")

      expect(listed).to eq [ "Braised pork" ]
    end

    it "shows every recipe for a search that isn't text" do
      get recipes_path(q: [ "egg" ])

      expect(response).to have_http_status(:ok)
      expect(listed.size).to eq 4
    end

    it "keeps the tag filter with an ingredient search" do
      get recipes_path(q: "egg", tags: [ "breakfast" ])

      expect(listed).to eq [ "Pancakes" ]
    end

    it "counts each tag among the recipes as searched, and a ticked tag at none as 0" do
      lunch = create(:tag, key: "lunch", kind: "meal")
      with_ingredients("Egg salad", "boiled eggs", tags: [ lunch ])

      get recipes_path(q: "egg", tags: [ "breakfast" ])

      expect(Nokogiri::HTML(response.body).css(".tag-catalog label").map { _1.text.squish })
        .to eq [ "Breakfast 1", "Lunch 1" ]

      get recipes_path(q: "rice", tags: [ "breakfast" ])

      expect(listed).to be_empty
      expect(Nokogiri::HTML(response.body).at_css(".tag-catalog label").text.squish).to eq "Breakfast 0"
    end

    it "leaves out tags that are unknown or aren't a list of keys" do
      get recipes_path(tags: [ "breakfast", "nonsense" ])
      expect(listed).to eq [ "Pancakes" ]

      get recipes_path(tags: { "a" => "breakfast" })
      expect(response).to have_http_status(:ok)
      expect(listed.size).to eq 4
    end

    it "takes the text as it is, so a % in it matches only a %" do
      get recipes_path(q: "%")

      expect(listed).to be_empty
    end

    it "finds a recipe for the meal plan by its name or one of its ingredients" do
      get search_recipes_path(q: "flour")

      expect(response.parsed_body.pluck("name")).to eq [ "Pancakes" ]
    end

    it "leaves sources out of the meal plan's search" do
      create(:recipe, user: user, name: "Braised pork", source: create(:source, user: user, name: "Mom's notebook"))

      get search_recipes_path(q: "mom")

      expect(response.parsed_body).to be_empty
    end
  end
end
