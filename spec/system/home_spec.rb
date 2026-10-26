require "rails_helper"

RSpec.describe "The home page", type: :system do
  def navbar_color = page.evaluate_script("getComputedStyle(document.querySelector('header')).backgroundColor")

  it "has the navbar in the hero's cream, as every page does, parted from the page by a line once scrolled" do
    user = create(:user)
    create_list(:recipe, 4, user: user)
    log_in_as user

    expect(navbar_color).to eq "rgb(247, 242, 237)" # the hero's cream
    expect(page).to have_no_css("header.is-scrolled")
    page.execute_script("window.scrollTo(0, 400)")
    expect(page).to have_css("header.is-scrolled")

    click_link "All Recipes"
    expect(page).to have_css("h1", text: "Recipes")
    expect(navbar_color).to eq "rgb(247, 242, 237)"
  end

  it "searches the recipes from the hero, opening the recipe list with the search" do
    user = create(:user)
    create(:recipe, user: user, name: "Mapo Tofu")
    create(:recipe, user: user, name: "Minestrone")
    log_in_as user

    fill_in "Search recipes by name, ingredient or source", with: "tofu"
    find_field("Search recipes by name, ingredient or source").send_keys(:enter)

    expect(page).to have_current_path(recipes_path(q: "tofu"))
    expect(page).to have_css(".recipe-row", count: 1, text: "Mapo Tofu")
    expect(page).to have_field("Search recipes by name, ingredient or source", with: "tofu")
  end

  it "keeps the hero on one phone screen: the photo across the top, then the intro down to the numbers" do
    allow(CleanRecipeService).to receive(:available?).and_return(true) # the assistant's button stays off a phone's
    page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: 390, height: 700) }
    log_in_as create(:user)

    photo = page.evaluate_script("document.querySelector('.home-photo-image').getBoundingClientRect().toJSON()")
    expect(photo).to include("left" => 0, "width" => 390)
    expect(page.evaluate_script("document.querySelector('.home-stats').getBoundingClientRect().bottom")).to be <= 700
    expect(page).to have_no_button("Ask the assistant", class: "home-actions-assistant")
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 390
  end
end
