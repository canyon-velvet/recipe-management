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

  it "fits the narrowest phone's width, even with a long username and drafts waiting" do
    allow(CleanRecipeService).to receive(:available?).and_return(true) # ✦ shows too
    resize(320)
    user = create(:user, username: "a_rather_long_username_for_a_phone")
    user.drafts.create!(source_url: "https://example.com/pancakes", status: :ready) # the account's dot shows too
    log_in_as user

    expect(page).to have_css(".account-dot")
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 320
  end

  [ 768, 1024 ].each do |width|
    it "keeps ☰ in reach beside the open assistant panel at #{width}px, where the panel covers the page" do
      allow(CleanRecipeService).to receive(:available?).and_return(true)
      resize(width)
      log_in_as create(:user, username: "a_rather_long_username")
      click_button "Open assistant"

      click_button "Menu"
      click_link "Meal Plans"
      expect(page).to have_css("h1", text: "Meal Plans")
      expect(page).to have_css(".assistant-panel")
    end
  end

  it "shows who's signed in atop the account menu, and an admin's items under their own label" do
    log_in_as create(:user, :admin, username: "home_cook")
    click_button "home_cook"

    within(".account-menu") do
      expect(find(".menu-who")).to have_text("home_cook").and have_text("Signed in")
      expect(page).to have_css(".menu-label", text: /admin/i)
      # For screen readers: the admin's items are a group named by the label, and the header isn't in the menu
      expect(find("[role='group'][aria-labelledby='account_menu_admin']")).to have_link("Invites")
      expect(page).to have_no_css("[role='menu'] .menu-who")
      expect(page).to have_css(".menu-item--logout", text: "Log out")
    end
  end

  it "imports a recipe from the account menu on any page, its first item, above the Draft box" do
    log_in_as create(:user, username: "home_cook")
    visit meal_plans_path
    click_button "home_cook"

    within(".account-menu") do
      expect(all("[role='menuitem']").map(&:text).first(2).map(&:squish)).to eq [ "Import a recipe", "Draft box" ]
      click_link "Import a recipe"
    end

    expect(page).to have_current_path(new_import_path)
    expect(page).to have_field("Recipe link")
  end

  it "leaves the admin's label and items out of everyone else's account menu" do
    log_in_as create(:user, username: "home_cook")
    click_button "home_cook"

    within(".account-menu") do
      expect(page).to have_link("Preferences")
      expect(page).to have_no_css(".menu-label")
      expect(page).to have_no_link("Invites")
    end
  end

  it "marks the page you're on and the language in use in ☰" do
    resize(1024)
    log_in_as user
    visit meal_plans_path
    click_button "Menu"

    within(".navbar-menu-list") do
      expect(page).to have_css(".menu-item--current[aria-current='page']", text: "Meal Plans")
      expect(page).to have_css("button.menu-item--current[aria-current='true'] svg", visible: :all)
      expect(page).to have_css("button.menu-item--current", text: "English")
      expect(page).to have_css(".menu-item", count: 5) # three links, two languages
    end
  end

  it "closes ☰ when the account menu opens, and the other way round" do
    resize(360)
    log_in_as create(:user, username: "home_cook")

    click_button "Menu"
    expect(page).to have_css(".navbar-menu-list", visible: true)

    click_button "home_cook"
    expect(page).to have_css(".account-menu", visible: true)
    expect(page).to have_no_css(".navbar-menu-list", visible: true)

    click_button "Menu"
    expect(page).to have_css(".navbar-menu-list", visible: true)
    expect(page).to have_no_css(".account-menu", visible: true)

    # Its own button still closes it
    click_button "Menu"
    expect(page).to have_no_css(".navbar-menu-list", visible: true)
  end

  it "keeps the username for screen readers where an icon shows instead" do
    resize(360)
    log_in_as create(:user, username: "home_cook")

    expect(page).to have_button("home_cook")
    expect(page).to have_css(".account-icon", visible: true)
    # The name is screen-reader-only: in the page, but a 1px clipped box
    expect(page.evaluate_script("document.querySelector('.account-name').getBoundingClientRect().width")).to be <= 1
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
