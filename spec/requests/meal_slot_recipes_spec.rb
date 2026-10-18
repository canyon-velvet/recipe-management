require "rails_helper"

RSpec.describe "Meals' recipes and the grocery list", type: :request do
  let(:user) { create(:user) }
  let(:plan) { user.meal_plans.create!(start_date: Date.new(2026, 10, 19), end_date: Date.new(2026, 10, 25)) }
  let(:curry) { create(:recipe, user: user, name: "Curry") }

  def slot(day, meal_type = "dinner") = plan.meal_slots.find_by!(day_of_week: day, meal_type: meal_type)

  def add(recipe, to:) = post(meal_slot_meal_slot_recipes_path(to), params: { meal_slot_recipe: { recipe_id: recipe.id } },
                                                                    as: :turbo_stream)

  before { post login_path, params: { username: user.username, password: "password" } }

  it "adds a recipe ticked for the grocery list when it's already ticked elsewhere in the week" do
    slot("monday").meal_slot_recipes.create!(recipe: curry, add_to_grocery_list: true)

    add curry, to: slot("tuesday")

    expect(slot("tuesday").meal_slot_recipes.sole.add_to_grocery_list).to be true
  end

  it "adds a recipe to a meal once" do
    add curry, to: slot("monday")
    add curry, to: slot("monday")

    expect(response).to have_http_status(:unprocessable_content)
    expect(slot("monday").recipes).to eq [ curry ]
  end

  it "adds a recipe to a meal once when it's added twice at once (a double click)" do
    slot("monday").meal_slot_recipes.create!(recipe: curry)
    # The second request got past the validation before the first one saved: the database refuses it
    allow_any_instance_of(MealSlotRecipe).to receive(:valid?).and_return(true)

    add curry, to: slot("monday")

    expect(response).to have_http_status(:unprocessable_content)
    expect(slot("monday").recipes).to eq [ curry ]
  end

  it "doesn't find another user's meals or grocery items" do
    their_plan = create(:user).meal_plans.create!(start_date: Date.new(2026, 10, 19), end_date: Date.new(2026, 10, 25))
    their_slot = their_plan.meal_slots.first
    their_meal = their_slot.meal_slot_recipes.create!(recipe: create(:recipe, user: their_plan.user),
                                                      add_to_grocery_list: false)
    SyncGroceryListService.new(their_plan).call
    their_item = their_plan.grocery_list.grocery_list_items.create!(ingredient: create(:ingredient, user: their_plan.user))

    add curry, to: their_slot
    expect(response).to have_http_status(:not_found)
    patch meal_slot_recipe_path(their_meal), params: { meal_slot_recipe: { add_to_grocery_list: "1" } }, as: :turbo_stream
    expect(response).to have_http_status(:not_found)
    delete meal_slot_recipe_path(their_meal), as: :turbo_stream
    expect(response).to have_http_status(:not_found)
    patch grocery_list_item_path(their_item), params: { in_pantry: "1" }, as: :turbo_stream
    expect(response).to have_http_status(:not_found)

    expect(their_meal.reload.add_to_grocery_list).to be false
    expect(their_item.reload.in_pantry).to be false
  end
end
