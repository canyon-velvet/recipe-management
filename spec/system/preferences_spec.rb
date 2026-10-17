require "rails_helper"

RSpec.describe "Preferences", type: :system do
  let(:user) { create(:user) }

  it "adds facts with Enter and removes them, from the account menu's Preferences page" do
    log_in_as user
    find(".account-toggle").click
    click_link "Preferences"

    within("#preferences_avoid") do
      fill_in("Avoid", with: "peanuts").send_keys(:enter)
      expect(page).to have_css(".preference-chip", text: "peanuts")
      expect(page).to have_field("Avoid", with: "")
      # The keyboard stays in the box, ready for the next one
      expect(page).to have_css("#avoid_preference_value:focus")
    end

    within("#preferences_household") do
      fill_in("Household", with: "2 adults and a toddler").send_keys(:enter)
      expect(page).to have_css(".preference-chip", text: "2 adults and a toddler")
      # One household fact: the box hides until it's removed, and the keyboard goes to the fact's remove button
      expect(page).to have_no_field("Household")
      expect(page).to have_css(".preference-remove:focus")

      click_button "Remove 2 adults and a toddler"
      expect(page).to have_no_css(".preference-chip")
      expect(page).to have_field("Household")
    end

    expect(user.preferences.pluck(:category, :value)).to eq [ [ "avoid", "peanuts" ] ]
  end

  it "saves the time zone as soon as one is picked" do
    log_in_as user
    visit preferences_path

    within("#time_zone") do
      expect(page).to have_select("Time zone", selected: "(GMT-06:00) Central Time (US & Canada)")
      select "(GMT+08:00) Beijing", from: "Time zone"
      expect(page).to have_text("Saved")
    end
    expect(user.reload.time_zone).to eq "Beijing"
  end
end
