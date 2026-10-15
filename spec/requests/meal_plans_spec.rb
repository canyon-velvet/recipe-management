require "rails_helper"

RSpec.describe "Meal plans", type: :request do
  let(:user) { create(:user) }

  before { post login_path, params: { username: user.username, password: "password" } }

  it "links each meal plan's card menu to its grocery list" do
    monday = Date.current.beginning_of_week(:monday)
    meal_plan = user.meal_plans.create!(start_date: monday, end_date: monday + 6.days)

    get meal_plans_path

    expect(response.body).to include(%(href="#{meal_plan_grocery_list_path(meal_plan)}">Grocery list</a>))
  end
end
