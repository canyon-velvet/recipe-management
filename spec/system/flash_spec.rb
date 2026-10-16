require "rails_helper"

RSpec.describe "Notices after an action", type: :system do
  let(:user) { create(:user) }

  it "floats a notice over the top of the page, and fades it away by itself" do
    log_in_as user

    notice = find(".flash--notice[role='status']", text: "Logged in.")
    expect(notice).to have_css(".flash-icon", text: "✓")
    # Over the page, not in it: nothing below moves down to make room
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.flash-list')).position")).to eq "fixed"

    using_wait_time(7) { expect(page).to have_no_css(".flash") }
  end

  it "closes a notice sooner with its ×" do
    log_in_as user

    within(".flash", text: "Logged in.") { click_button "Close" }
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

  it "keeps a problem until it's closed, so it isn't missed" do
    visit login_path
    fill_in "Username", with: user.username
    fill_in "Password", with: "wrong"
    click_button "Log in"

    alert = find(".flash--alert[role='alert']", text: "Incorrect username or password.")
    expect(alert).to have_css(".flash-icon", text: "⚠")

    sleep 6 # past the time a notice fades
    expect(page).to have_css(".flash--alert", text: "Incorrect username or password.")
  end
end
