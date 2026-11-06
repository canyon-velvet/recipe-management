require "rails_helper"

RSpec.describe "Choosing a recipe's icon", type: :system do
  let(:user) { create(:user) }

  before { log_in_as user }

  def tile = find(".recipe-icon-tile")

  it "taps one from the pop-up beside the name, which closes with it chosen, and none for the placeholder" do
    recipe = create(:recipe, user: user, name: "Bibimbap", icon: "🍜")
    visit edit_recipe_path(recipe)
    expect(tile).to have_text("🍜")

    click_button "Choose an icon"
    within("dialog[open]") do
      expect(page).to have_css("h3", text: "Choose an icon")
      expect(page).to have_css("button[aria-pressed=true]", exact_text: "🍜")
      click_button "🍣"
    end
    expect(page).to have_no_css("dialog[open]")
    expect(tile).to have_text("🍣")
    click_button "Update recipe"
    expect(page).to have_text("Recipe updated.")
    expect(page).to have_css(".recipe-heading-icon", text: "🍣")

    visit edit_recipe_path(recipe)
    click_button "Choose an icon"
    within("dialog[open]") { click_button "No icon" }
    expect(tile).to have_css("img[src*='recipe-placeholder']", visible: true)
    expect(tile).to have_no_text("🍣")
    click_button "Update recipe"
    expect(page).to have_text("Recipe updated.")
    expect(recipe.reload.icon).to be_nil
  end

  it "keeps an icon not in the grid first, the one it started with from a tag" do
    recipe = create(:recipe, user: user, icon: "🇰🇷")
    visit edit_recipe_path(recipe)

    click_button "Choose an icon"
    choices = all("dialog[open] .icon-picker-choice")
    expect(choices.first[:"aria-label"]).to eq "No icon"
    expect(choices[1]).to have_text("🇰🇷")
    expect(choices[1][:"aria-pressed"]).to eq "true"
  end

  it "starts a new recipe on the placeholder, and fits the grid on a phone" do
    page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: 390, height: 844) }
    visit new_recipe_path
    expect(tile).to have_css("img[src*='recipe-placeholder']", visible: true)

    click_button "Choose an icon"
    expect(page).to have_css("button[aria-pressed=true][aria-label='No icon']")
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 390
    width = page.evaluate_script("document.querySelector('dialog[open]').getBoundingClientRect().right")
    expect(width).to be <= 390
  end
end
