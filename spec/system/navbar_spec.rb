require "rails_helper"

RSpec.describe "The navbar", type: :system do
  let(:user) { create(:user) }

  def resize(width) = page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: width, height: 800) }

  it "shows its links on a wide window" do
    log_in_as user

    expect(page).to have_link("Meal Plans")
    expect(page).to have_no_button("Menu")
  end

  it "folds its links and the language switcher into ☰ on a narrower window" do
    resize(1024)
    log_in_as user

    expect(page).to have_no_link("Meal Plans")
    expect(page).to have_no_button("Language")

    click_button "Menu"
    click_link "Meal Plans"
    expect(page).to have_css("h1", text: "Meal Plans")

    click_button "Menu"
    click_button "中文"
    expect(page).to have_button("菜单") # the page is now in Chinese
  end

  it "folds them beside the open assistant panel, which leaves the links too little room" do
    allow(CleanRecipeService).to receive(:available?).and_return(true)
    log_in_as user
    expect(page).to have_link("Meal Plans")

    click_button "Open assistant"
    expect(page).to have_no_link("Meal Plans")
    expect(page).to have_button("Menu")

    within(".assistant-panel") { click_button "Close assistant" }
    expect(page).to have_link("Meal Plans")
  end
end
