require "rails_helper"

RSpec.describe "The grocery list", type: :system do
  let(:user) { create(:user) }
  let(:monday) { Date.current.beginning_of_week(:monday) }
  let(:meal_plan) { user.meal_plans.create!(start_date: monday, end_date: monday + 6.days, name: "Busy week") }

  before do
    { "Scallions" => [ "produce", 2 ], "Tomatoes" => [ "produce", 1 ], "Soy sauce" => [ "spices_seasonings", 1 ] }
      .each do |name, (aisle_key, count)|
        ingredient = create(:ingredient, user: user, name: name, aisle_key: aisle_key)
        meal_plan.grocery_list.grocery_list_items.create!(ingredient: ingredient, occurrence_count: count)
      end
    log_in_as user
    visit meal_plan_grocery_list_path(meal_plan)
  end

  def aisle(name) = find(".grocery-aisle-card", text: name.upcase)

  it "shows what's left by aisle, with how many recipes use each" do
    expect(page).to have_css("h1", text: "Grocery List")
    expect(page).to have_link("Busy week", href: meal_plan_path(meal_plan))
    expect(page).to have_text("3 to buy · 0 already have")
    expect(aisle("Produce")).to have_css(".grocery-count-badge", exact_text: "2 recipes")
    expect(aisle("Produce")).to have_css(".grocery-aisle-count", exact_text: "2")
  end

  it "moves a ticked item to Already have, and puts it back in its aisle when unticked" do
    check "Soy sauce"

    within("#pantry_items") { expect(page).to have_text("Soy sauce") }
    expect(page).to have_text("2 to buy · 1 already have")
    expect(page).to have_no_css(".grocery-aisle-card", text: "SPICES") # the aisle is gone once it's empty

    within("#pantry_items") { uncheck "Soy sauce" }

    expect(aisle("Spices & Seasonings")).to have_text("Soy sauce")
    expect(page).to have_text("3 to buy · 0 already have")
    expect(page).to have_no_css("#pantry_items")
  end
end
