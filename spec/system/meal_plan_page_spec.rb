require "rails_helper"

RSpec.describe "A week's plan", type: :system do
  let(:user) { create(:user) }
  let(:monday) { Date.current.beginning_of_week(:monday) }
  let(:meal_plan) { user.meal_plans.create!(start_date: monday, end_date: monday + 6.days) }

  # A long name, to check that it truncates instead of widening the page on a phone
  let(:recipe_name) { "Overnight oats with stewed apples, toasted walnuts and a spoonful of yoghurt" }

  before { create(:recipe, user: user, name: recipe_name) }

  def resize(width) = page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: width, height: 900) }
  def top(element) = page.evaluate_script("arguments[0].getBoundingClientRect().top", element)

  it "is a week × meal grid on a wide screen" do
    log_in_as user
    visit meal_plan_path(meal_plan)

    headings = all(".meal-day-heading")
    expect(headings.size).to eq 7
    expect(headings.map { top(_1) }.uniq.size).to eq 1 # the days side by side
    expect(page).to have_css(".meal-week-meal-name", text: /breakfast/i, visible: true)
  end

  it "is a card per day on a phone, where a recipe can be added, ticked and removed" do
    resize(390)
    log_in_as user
    visit meal_plan_path(meal_plan)

    days = all(".meal-day")
    expect(top(days[1])).to be > top(days[0]) # one above the other
    expect(page).to have_no_css(".meal-week-meal-name", visible: true)
    expect(find(".meal-day--today")).to have_text("Today")

    slot = meal_plan.meal_slots.find_by!(day_of_week: "sunday", meal_type: "breakfast")
    within("#meal_slot_#{slot.id}") { click_button "＋ Add" }
    within("dialog[open]") do
      fill_in placeholder: "Search recipes or ingredients...", with: "oats"
      find("li", text: "Overnight oats").click
    end
    within("#meal_slot_#{slot.id}") { expect(page).to have_link(recipe_name) }
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 390
    expect(page).to have_text("1 recipe planned") # the header redrawn with the meal
    expect(page).to have_css("#meal_plan_header .meal-plan-header", count: 1)

    within("#meal_slot_#{slot.id}") do
      check "Put #{recipe_name} on the grocery list"
      expect(page).to have_css(".meal-pill--on-list") # the server's redraw
      click_button "Remove #{recipe_name} from the plan"
      expect(page).to have_no_link(recipe_name)
    end
    expect(page).to have_text("0 recipes planned")
  end
end
