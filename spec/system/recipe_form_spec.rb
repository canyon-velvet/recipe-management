require "rails_helper"

RSpec.describe "The recipe form's sidebar", type: :system do
  let(:user) { create(:user) }
  let(:recipe) { create(:recipe, user: user) }

  def resize(width, height) = page.driver.with_playwright_page { |pw| pw.set_viewport_size(width:, height:) }
  def top(selector) = page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().top")
  def details_position = page.evaluate_script("getComputedStyle(document.querySelector('.recipe-form-details')).position")

  it "stays in view only in a window tall enough to show all of it" do
    log_in_as user

    resize(1280, 1000)
    visit edit_recipe_path(recipe)
    expect(details_position).to eq "sticky"

    resize(1280, 800)
    expect(details_position).to eq "static"
  end

  it "goes below the content on a phone, with Save at its end" do
    resize(390, 844)
    log_in_as user
    visit edit_recipe_path(recipe)

    expect(top(".recipe-form-details")).to be > top(".recipe-form-main")
    expect(top(".recipe-form-actions")).to be > top("#recipe_source_url")
  end

  it "goes below the content beside the open assistant panel, where there isn't room for both" do
    allow(CleanRecipeService).to receive(:available?).and_return(true)
    resize(1280, 1000)
    log_in_as user
    visit edit_recipe_path(recipe)
    expect(top(".recipe-form-details")).to eq top(".recipe-form-main")

    click_button "Open assistant"
    expect(page).to have_css("body.assistant-open")
    expect(top(".recipe-form-details")).to be > top(".recipe-form-main")
  end
end
