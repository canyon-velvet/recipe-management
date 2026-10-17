require "rails_helper"

RSpec.describe "Importing from the recipe list's pop-up", type: :system do
  let(:user) { create(:user) }

  before do
    allow(CleanRecipeService).to receive(:available?).and_return(true)
    log_in_as user
    visit recipes_path
    click_link "Import recipe"
  end

  it "starts an import from a link, and goes to the Draft box" do
    within("dialog[open]") do
      expect(page).to have_css("h2", text: "Bring in a recipe")
      fill_in "Recipe link", with: "https://example.com/apple-cake"
      click_button "Import"
    end

    expect(page).to have_text("Importing… the recipe will wait in your Draft box.")
    expect(user.drafts.sole.source_url).to eq "https://example.com/apple-cake"
  end

  it "opens the paste box on its chip" do
    within("dialog[open]") do
      expect(page).to have_no_field("Paste the recipe text instead")
      find(".import-paste-toggle").click
      fill_in "Paste the recipe text instead", with: "Apple cake\n2 apples\nBake for 40 minutes"
      click_button "Import"
    end

    expect(page).to have_text("Importing… the recipe will wait in your Draft box.")
    expect(user.drafts.sole.source_text).to include("2 apples")
  end

  it "shows a problem on the import page" do
    within("dialog[open]") do
      fill_in "Recipe link", with: "ftp://example.com/apple-cake"
      click_button "Import"
    end

    expect(page).to have_text("That doesn't look like a web link")
    expect(page).to have_css("h2", text: "Bring in a recipe")
  end

  it "closes on Cancel and on ×" do
    within("dialog[open]") { click_link "Cancel" }
    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_current_path(recipes_path)

    click_link "Import recipe"
    within("dialog[open]") { click_button "Close" }
    expect(page).to have_no_css("dialog[open]")
  end
end
