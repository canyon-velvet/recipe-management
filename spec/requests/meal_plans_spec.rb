require "rails_helper"

RSpec.describe "Meal plans", type: :request do
  let(:user) { create(:user) }
  let(:monday) { Date.new(2026, 10, 12) }

  before { post login_path, params: { username: user.username, password: "password" } }

  around { |example| travel_to(monday + 4.days) { example.run } }

  def plan_week(start_date, **attributes)
    user.meal_plans.create!(start_date: start_date, end_date: start_date + 6.days, **attributes)
  end

  it "links each meal plan's row to its grocery list" do
    meal_plan = plan_week(monday)

    get meal_plans_path

    expect(response.body).to include(%(href="#{meal_plan_grocery_list_path(meal_plan)}">Grocery list</a>))
  end

  it "groups the weeks by the month they start in, newest first" do
    plan_week(monday, name: "Busy week")
    plan_week(monday - 14.days, name: "Harvest week")

    get meal_plans_path

    expect(response.body.scan(/>((?:October|September) 2026|Busy week|Harvest week)</).flatten)
      .to eq [ "October 2026", "Busy week", "September 2026", "Harvest week" ]
  end

  it "marks this week and next week, and shows how many meals each has planned" do
    this_week = plan_week(monday)
    plan_week(monday + 7.days)
    this_week.meal_slots.find_by!(day_of_week: "monday", meal_type: "dinner").recipes << create(:recipe, user: user)

    get meal_plans_path

    expect(response.body).to include("This week", "Next week", "1 of 28 meals", "0 of 28 meals")
    expect(response.body.scan("meal-plan-row--current").size).to eq 1
  end
end
