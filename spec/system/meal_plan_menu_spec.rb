require "rails_helper"

RSpec.describe "A meal plan card's menu", type: :system do
  let(:user) { create(:user) }

  it "opens the week's grocery list, and is closed again on Back" do
    monday = Date.current.beginning_of_week(:monday)
    user.meal_plans.create!(start_date: monday, end_date: monday + 6.days)

    log_in_as user
    click_link "Meal Plans"
    find(".section-card [data-action*='dropdown#toggle']").click
    click_link "Grocery list"
    expect(page).to have_css("h1", text: "Grocery List")

    page.go_back
    expect(page).to have_css(".section-card")
    expect(page).to have_no_link("Grocery list") # the menu is closed, so its links are hidden
  end
end
