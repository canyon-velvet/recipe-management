require "rails_helper"

RSpec.describe "Notices after an action", type: :system do
  let(:user) { create(:user) }

  it "shows a notice as a card that stays until it's closed" do
    log_in_as user

    notice = find(".flash--notice[role='status']", text: "Logged in.")
    expect(notice).to have_css(".flash-icon", text: "✓")

    within(notice) { click_button "Close" }
    expect(page).to have_no_css(".flash")
  end

  it "doesn't show an old notice again on Back" do
    log_in_as user
    expect(page).to have_css(".flash", text: "Logged in.")

    click_link "Meal Plans"
    expect(page).to have_no_css(".flash")
    page.go_back

    expect(page).to have_current_path(root_path)
    expect(page).to have_no_css(".flash")
  end

  it "shows a problem as an alert" do
    visit login_path
    fill_in "Username", with: user.username
    fill_in "Password", with: "wrong"
    click_button "Log in"

    expect(page).to have_css(".flash--alert[role='alert']", text: "Incorrect username or password.")
    expect(page).to have_css(".flash--alert .flash-icon", text: "⚠")
  end
end
