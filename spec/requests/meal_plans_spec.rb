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

  describe "the new plan's weeks" do
    def week_input(selector) = Nokogiri::HTML(response.body).at("input[name='meal_plan[start_date]']#{selector}")
    def checked_week = week_input("[checked]")["value"]

    it "chooses next week, or this week on a Monday" do
      get new_meal_plan_path
      expect(checked_week).to eq (monday + 7.days).iso8601

      travel_to(monday)
      get new_meal_plan_path
      expect(checked_week).to eq monday.iso8601
    end

    it "can't choose a week that's already planned, and chooses Other… when all are" do
      plan_week(monday + 7.days)

      get new_meal_plan_path
      expect(week_input("[value='#{monday + 7.days}']")["disabled"]).to eq "disabled"
      expect(checked_week).to eq (monday + 14.days).iso8601

      plan_week(monday + 14.days)
      get new_meal_plan_path
      expect(checked_week).to eq ""
    end
  end

  it "marks this week and next week, and shows how many meals each has planned" do
    this_week = plan_week(monday)
    plan_week(monday + 7.days)
    this_week.meal_slots.find_by!(day_of_week: "monday", meal_type: "dinner").recipes << create(:recipe, user: user)

    get meal_plans_path

    expect(response.body).to include("This week", "Next week", "1 of 28 meals", "0 of 28 meals")
    expect(response.body.scan("meal-plan-row--current").size).to eq 1
  end

  describe "a week's plan" do
    let(:meal_plan) { plan_week(monday) }

    it "heads it with the week, how many recipes are planned, and what's left to buy" do
      recipe = create(:recipe, user: user, name: "Mapo tofu")
      meal_plan.meal_slots.find_by!(day_of_week: "monday", meal_type: "dinner")
               .meal_slot_recipes.create!(recipe: recipe, add_to_grocery_list: true)
      ingredients = create_list(:ingredient, 2, user: user).map { |ingredient| { ingredient: ingredient } }
      meal_plan.grocery_list.grocery_list_items.create!(ingredients)

      get meal_plan_path(meal_plan)

      page = Nokogiri::HTML(response.body)
      expect(page.at_css(".meal-plan-summary").text.squish).to eq "Oct 12 – Oct 18, 2026 · 1 recipe planned"
      expect(page.at_css(".meal-plan-to-buy").text).to eq "2 to buy"
      expect(page.css(".meal-day").size).to eq 7
      expect(page.at_css(".meal-pill--on-list .meal-pill-name").text).to eq "Mapo tofu"
    end

    it "names the recipe search pop-up by its heading" do
      get meal_plan_path(meal_plan)

      page = Nokogiri::HTML(response.body)
      heading_id = page.at_css("dialog[data-recipe-select-target=dialog]")["aria-labelledby"]
      expect(page.at_css("[id='#{heading_id}']").text).to eq "Choose a recipe"
    end

    it "speaks Chinese too" do
      patch locale_path, params: { locale: "zh-CN" }

      get meal_plan_path(meal_plan)

      expect(Nokogiri::HTML(response.body).at_css(".meal-plan-summary").text.squish)
        .to eq "10月12日 – 2026年10月18日 · 已安排 0 道菜谱"
    end
  end
end
