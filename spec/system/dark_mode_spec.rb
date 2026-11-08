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

  it "keeps white text on the tour's black strip white" do
    color_scheme("dark")
    visit login_path
    click_button "Watch the tour"

    expect(style(".tour-close", "color")).to eq "rgb(255, 255, 255)"
  end
end
