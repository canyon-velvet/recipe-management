require "rails_helper"

# The core loop, end to end: recipes → a week's meal plan → a grocery list grouped by aisle → skip what I have.
# Also the README demo: `RECORD_VIDEO=1 bundle exec rspec spec/system/plan_the_week_spec.rb`.
RSpec.describe "Planning the week", type: :system do
  let(:user) { create(:user, username: "home_cook", password: "secret123") }

  before do
    chinese = create(:tag, key: "chinese", kind: "cuisine")
    dinner = create(:tag, key: "dinner", kind: "meal")
    breakfast = create(:tag, key: "breakfast", kind: "meal")
    quick = create(:tag, key: "quick", kind: "convenience")

    create_recipe user, "Tomato and egg stir-fry", tags: [ chinese, dinner, quick ],
                  ingredients: { "Tomatoes" => "produce", "Eggs" => "dairy_eggs", "Scallions" => "produce",
                                 "Soy sauce" => "spices_seasonings" }
    create_recipe user, "Mapo tofu", tags: [ chinese, dinner ],
                  ingredients: { "Tofu" => "produce", "Ground pork" => "meat_seafood", "Scallions" => "produce",
                                 "Doubanjiang" => "spices_seasonings" }
    create_recipe user, "Overnight oats", tags: [ breakfast, quick ],
                  ingredients: { "Rolled oats" => "pantry", "Milk" => "dairy_eggs", "Blueberries" => "produce" }
  end

  it "turns two dinners into a grocery list grouped by aisle", video: "plan_the_week" do
    log_in_as user, password: "secret123"

    click_link "All Recipes"
    expect(page).to have_text("Tomato and egg stir-fry")
    expect(page).to have_text("Mapo tofu")
    expect(page).to have_text("Overnight oats")

    click_link "Meal Plans"
    click_link "New meal plan"
    click_button "Create"
    expect(page).to have_text("Meal plan created.")

    meal_plan = user.meal_plans.sole
    plan_dinner meal_plan, :monday, "Tomato and egg stir-fry", search: "tomato"
    plan_dinner meal_plan, :wednesday, "Mapo tofu", search: "mapo"

    click_link "Grocery list"
    # Aisles in shopping order; the oats weren't planned, so none of their ingredients are listed.
    expect(page.all(".grocery-card-header", count: 4).map(&:text))
      .to eq [ "Produce", "Meat & Seafood", "Dairy & Eggs", "Spices & Seasonings" ]
    expect(grocery_item("Scallions")).to have_css(".grocery-count-badge", exact_text: "2")
    expect(page).to have_no_text("Rolled oats")

    grocery_item("Soy sauce").check
    within("#pantry_items") { expect(page).to have_text("Soy sauce") }
    expect(find(".grocery-aisle-card", text: "Spices & Seasonings")).to have_no_text("Soy sauce")
  end

  private

  # Adds the recipe to that day's dinner through the search pop-up, then ticks it for the grocery list.
  def plan_dinner(meal_plan, day, recipe_name, search:)
    slot = meal_plan.meal_slots.find_by!(day_of_week: day, meal_type: "dinner")
    find("button[data-meal-slot-id='#{slot.id}']").click

    within("dialog[open]") do
      fill_in placeholder: "Search recipes...", with: search
      find("li", text: recipe_name).click
    end

    within("#meal_slot_#{slot.id}") do
      expect(page).to have_text(recipe_name)
      find("input[type=checkbox]").check
      # The cream pill comes from the server's re-render, so the grocery list has been synced by now.
      expect(page).to have_css(".meal-pill--on-list input[type=checkbox]:checked")
    end
  end

  def grocery_item(name) = find(".grocery-item", text: name)
end
