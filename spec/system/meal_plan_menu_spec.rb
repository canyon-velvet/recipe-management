require "rails_helper"

RSpec.describe "A meal plan's row", type: :system do
  let(:user) { create(:user) }
  let(:monday) { Date.current.beginning_of_week(:monday) }
  let!(:meal_plan) { user.meal_plans.create!(start_date: monday, end_date: monday + 6.days) }

  it "opens the week's grocery list" do
    log_in_as user
    visit meal_plans_path
    within(".meal-plan-row") { click_link "Grocery list" }

    expect(page).to have_css("h1", text: "Grocery List")
  end

  it "has its ⋮ menu closed again on Back" do
    log_in_as user
    visit meal_plans_path
    find(".meal-plan-row [data-action*='dropdown#toggle']").click
    expect(page).to have_link("Delete")

    # Leaves with the menu still open, as clicking anywhere would close it first
    page.execute_script("Turbo.visit('#{meal_plan_grocery_list_path(meal_plan)}')")
    expect(page).to have_css("h1", text: "Grocery List")

    page.go_back
    expect(page).to have_css(".meal-plan-row")
    expect(page).to have_no_link("Delete") # the menu is closed, so its links are hidden
  end
end
