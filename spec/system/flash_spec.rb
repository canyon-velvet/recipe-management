require "rails_helper"

RSpec.describe "Notices after an action", type: :system do
  let(:user) { create(:user) }

  it "hangs a notice from the top of the window, over the navbar, and fades it away by itself" do
    log_in_as user

    notice = find(".flash--notice[role='status']", text: "Logged in.")
    expect(notice).to have_css(".flash-icon", text: "✓")
    # Over the page, not in it: nothing below moves down to make room
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.flash-list')).position")).to eq "fixed"
    expect(page.evaluate_script("document.querySelector('.flash').getBoundingClientRect().top")).to eq 0

    using_wait_time(7) { expect(page).to have_no_css(".flash") }
  end

  it "hangs it from the navbar's bottom edge on a small screen, where the navbar is full" do
    page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: 768, height: 800) }
    log_in_as user

    expect(page).to have_css(".flash--notice", text: "Logged in.")
    expect(page.evaluate_script("document.querySelector('.flash').getBoundingClientRect().top")).to eq 80
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

    within(".flash--alert") { click_button "Close" }
    expect(page).to have_no_css(".flash")
  end

  it "ends above where the navbar's menus open, so an open menu isn't covered" do
    log_in_as user
    expect(page).to have_css(".flash--notice", text: "Logged in.")
    find(".account-toggle").click

    notice_bottom = page.evaluate_script("document.querySelector('.flash').getBoundingClientRect().bottom")
    menu_top = page.evaluate_script("document.querySelector('.account-menu').getBoundingClientRect().top")
    expect(notice_bottom).to be < menu_top
  end

  it "keeps a notice while the pointer is on it, and fades it once the pointer leaves" do
    log_in_as user

    find(".flash--notice", text: "Logged in.").hover
    sleep 6 # past the time it would fade
    expect(page).to have_css(".flash--notice", text: "Logged in.")

    find(".logo-text").hover # away from the notice
    using_wait_time(4) { expect(page).to have_no_css(".flash") }
  end
end
