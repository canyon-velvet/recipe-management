require "rails_helper"

RSpec.describe "Home page", type: :request do
  let(:user) { create(:user) }
  let(:monday) { Date.current.beginning_of_week(:monday) }

  def plan_this_week = user.meal_plans.create!(start_date: monday, end_date: monday + 6.days)

  def tonight_slot(plan)
    plan.meal_slots.find_by!(day_of_week: MealPlan::DAYS_OF_WEEK[Date.current.days_to_week_start(:monday)],
                             meal_type: "dinner")
  end

  it "needs a login" do
    get root_path

    expect(response).to redirect_to(login_path)
  end

  it "counts the recipes, this week's meals and what's left to buy, and shows tonight's dinner" do
    recipes = create_list(:recipe, 3, user: user)
    plan = plan_this_week
    tonight_slot(plan).recipes << recipes[0] << recipes[1]
    items = create_list(:ingredient, 3, user: user).map { |ingredient| { ingredient: ingredient } }
    plan.grocery_list.grocery_list_items.create!(items)
    plan.grocery_list.grocery_list_items.last.update!(in_pantry: true)
    log_in_as user

    get root_path

    stats = Nokogiri::HTML(response.body).css(".home-stat-value").map { |value| value.text.squish }
    expect(stats).to eq [ "3", "2 dishes", "2" ]
    expect(response.body).to include(recipe_path(recipes[0]), "+1")
    # A phone's status bar matches the cream navbar (on every page)
    expect(response.body).to include(%(<meta name="theme-color" content="#F7F2ED">))
  end

  it "offers to plan the week when nothing is planned for tonight" do
    log_in_as user

    get root_path
    expect(response.body).to include("Nothing planned yet", %(href="#{new_meal_plan_path}"))

    plan = plan_this_week
    get root_path
    expect(response.body).to include(%(href="#{meal_plan_path(plan)}"))
  end

  it "works out tonight in the user's time zone" do
    # Sunday 18 Oct, 10 pm in Chicago: already Monday in UTC
    travel_to Time.utc(2026, 10, 19, 3)
    sunday_dinner = create(:recipe, user: user, name: "Sunday roast")
    plan = user.meal_plans.create!(start_date: Date.new(2026, 10, 12), end_date: Date.new(2026, 10, 18))
    plan.meal_slots.find_by!(day_of_week: "sunday", meal_type: "dinner").recipes << sunday_dinner
    log_in_as user

    get root_path
    expect(Nokogiri::HTML(response.body).at_css(".home-tonight").text).to include("Sunday roast")

    user.update!(time_zone: "UTC")
    get root_path
    expect(Nokogiri::HTML(response.body).at_css(".home-tonight").text).to include("Nothing planned yet")
  end

  it "shows the latest recipes, and leaves the section out for a new account" do
    log_in_as user

    get root_path
    expect(response.body).not_to include("Recently updated")

    create(:recipe, user: user, name: "Mapo Tofu")
    get root_path
    expect(response.body).to include("Recently updated", "Mapo Tofu")
  end

  it "is in Chinese for a Chinese visitor" do
    log_in_as user
    patch locale_path, params: { locale: "zh-CN" }

    get root_path

    expect(response.body).to include("你喜欢的每一道菜，", "都在这里。", "还没有安排")
  end
end
