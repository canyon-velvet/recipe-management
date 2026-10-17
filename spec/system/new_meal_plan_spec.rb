require "rails_helper"

RSpec.describe "Starting a meal plan", type: :system do
  let(:user) { create(:user) }
  let(:this_monday) { Date.current.beginning_of_week(:monday) }

  before do
    user.meal_plans.create!(start_date: this_monday, end_date: this_monday + 6.days, name: "Busy week")
    log_in_as user
    visit meal_plans_path
    click_link "New meal plan"
  end

  it "plans the first free week from the pop-up over the list" do
    within("dialog[open]") do
      expect(page).to have_field("This week", disabled: true, visible: :all)
      expect(page).to have_css(".week-chip", text: /This week\s+Already planned/)
      expect(page).to have_checked_field("Next week", visible: :all)
      fill_in "Name (optional)", with: "Week of soups"
      click_button "Create"
    end

    expect(page).to have_text("Meal plan created.")
    expect(user.meal_plans.order(:start_date).last)
      .to have_attributes(start_date: this_monday + 7.days, name: "Week of soups")
  end

  it "plans another week from any day in it" do
    within("dialog[open]") do
      expect(page).to have_no_field("Week", type: "date")
      find(".week-chip", text: "Other…").click
      find("input[type=date]").set((this_monday + 37.days).iso8601) # a Wednesday, five weeks on
      click_button "Create"
    end

    expect(page).to have_text("Meal plan created.")
    expect(user.meal_plans.order(:start_date).last.start_date).to eq this_monday + 35.days
  end

  it "shows a week that's already planned as a problem" do
    within("dialog[open]") do
      find(".week-chip", text: "Other…").click
      find("input[type=date]").set(this_monday.iso8601)
      click_button "Create"
    end

    expect(page).to have_text("already has a meal plan for this week")
    expect(user.meal_plans.count).to eq 1
  end

  it "closes on Cancel, leaving the list as it was" do
    within("dialog[open]") { click_link "Cancel" }

    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_current_path(meal_plans_path)
  end

  it "closes on ×" do
    within("dialog[open]") do
      expect(page).to have_css("h2", text: "Plan a week")
      click_button "Close"
    end

    expect(page).to have_no_css("dialog[open]")
  end
end
