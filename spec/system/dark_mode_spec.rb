require "rails_helper"

RSpec.describe "Dark mode", type: :system do
  def color_scheme(scheme) = page.driver.with_playwright_page { _1.emulate_media(colorScheme: scheme) }
  def style(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector('#{selector}')).#{property}")
  end

  it "follows the phone's or computer's own setting: warm espresso when it's dark, the usual colours when it's light" do
    recipe = create(:recipe, description: "Rice and a **fried egg**.")
    log_in_as recipe.user

    color_scheme("dark")
    visit recipe_path(recipe)
    expect(style("body", "backgroundColor")).to eq "rgb(26, 21, 18)" # the dark coffee page
    expect(style(".recipe-description strong", "color")).to eq "rgb(241, 234, 226)" # formatted text too
    expect(style("html", "colorScheme")).to eq "dark" # the browser's own parts: checkboxes, scrollbars

    color_scheme("light")
    expect(style("body", "backgroundColor")).not_to eq "rgb(26, 21, 18)"
    expect(style(".recipe-description strong", "color")).not_to eq "rgb(241, 234, 226)"
  end

  it "shows the phone's account icon in the caramel, as the rest of the navbar" do
    user = create(:user)
    log_in_as user
    color_scheme("dark")
    page.driver.with_playwright_page { _1.set_viewport_size(width: 390, height: 844) }
    visit recipes_path

    expect(style(".account-icon svg", "color")).to eq "rgb(212, 180, 140)" # the caramel, not the light mode's brown
  end

  it "turns dark or light from the account menu at once, whatever the device's setting, and stays so" do
    user = create(:user, username: "home_cook")
    color_scheme("light")
    log_in_as user

    click_button "home_cook"
    click_button "Dark"
    expect(style("body", "backgroundColor")).to eq "rgb(26, 21, 18)"
    expect(page).to have_css("#appearance [aria-checked=true]", text: "Dark") # saved, and the switch redrawn
    expect(user.reload.appearance).to eq "dark"
    visit recipes_path
    expect(style("body", "backgroundColor")).to eq "rgb(26, 21, 18)"

    color_scheme("dark")
    click_button "home_cook"
    click_button "Light"
    expect(style("body", "backgroundColor")).not_to eq "rgb(26, 21, 18)"

    click_button "Auto" # the device's dark again
    expect(style("body", "backgroundColor")).to eq "rgb(26, 21, 18)"
    expect(page).to have_css("#appearance [aria-checked=true]", text: "Auto")
    expect(user.reload.appearance).to eq "auto"
  end

  it "keeps white text on the tour's black strip white" do
    color_scheme("dark")
    visit login_path
    click_button "Watch the tour"

    expect(style(".tour-close", "color")).to eq "rgb(255, 255, 255)"
  end
end
