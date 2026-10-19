require "rails_helper"

RSpec.describe "Importing from the recipe list's pop-up", type: :system do
  let(:user) { create(:user) }

  before do
    create(:source, user: user, name: "小红书")
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

  it "switches to Text for pasted recipe text, with where it's from instead of a link" do
    within("dialog[open]") do
      expect(page).to have_checked_field("Link")
      expect(page).to have_no_field("Recipe text")
      choose "Text", allow_label_click: true
      expect(page).to have_no_field("Recipe link")
      choose "小红书", allow_label_click: true
      fill_in "Recipe text", with: "Apple cake\n2 apples\nBake for 40 minutes"
      click_button "Import"
    end

    expect(page).to have_text("Importing… the recipe will wait in your Draft box.")
    expect(user.drafts.sole).to have_attributes(source_url: nil, source_text: include("2 apples"),
                                                data: { "source_name" => "小红书" })
  end

  it "asks where pasted text is from before sending" do
    within("dialog[open]") do
      choose "Text", allow_label_click: true
      fill_in "Recipe text", with: "Apple cake"
      click_button "Import"

      expect(page).to have_field("Recipe text", with: "Apple cake") # still here, not sent
    end
    expect(user.drafts).to be_empty
  end

  it "has someone with no sources yet make one before sending" do
    user.sources.destroy_all
    visit recipes_path
    click_link "Import recipe"

    within("dialog[open]") do
      choose "Text", allow_label_click: true
      fill_in "Recipe text", with: "Apple cake"
      expect(page).to have_field("Search sources...") # open already: there are no chips to tap
      click_button "Import"
      expect(page).to have_field("Recipe text", with: "Apple cake") # still here, not sent

      # A name typed but neither picked nor created isn't a source either
      fill_in "Search sources...", with: "Grandma"
      find_field("Recipe text").click # closes the list of matches
      click_button "Import"
      expect(page).to have_field("Recipe text", with: "Apple cake")
      expect(user.drafts).to be_empty

      fill_in "Search sources...", with: "Grandma"
      find(".autocomplete-item--create").click
    end
    within("dialog[open] dialog[open]") { click_button "Save" } # the pop-up within the import pop-up
    within("dialog[open]") do
      expect(page).to have_checked_field("Grandma", visible: :all)
      click_button "Import"
    end

    expect(page).to have_text("Importing… the recipe will wait in your Draft box.")
    expect(user.drafts.sole.data).to eq("source_name" => "Grandma")
  end

  it "imports a link for someone with no sources yet, whose source box only Text and Screenshot need" do
    user.sources.destroy_all
    visit recipes_path
    click_link "Import recipe"

    within("dialog[open]") do
      fill_in "Recipe link", with: "https://example.com/apple-cake"
      click_button "Import"
    end

    expect(page).to have_text("Importing… the recipe will wait in your Draft box.")
  end

  it "leaves out text typed in Text when Link is chosen again" do
    within("dialog[open]") do
      choose "Text", allow_label_click: true
      fill_in "Recipe text", with: "Apple cake"
      choose "Link", allow_label_click: true
      expect(page).to have_no_field("Recipe text")
      fill_in "Recipe link", with: "https://example.com/apple-cake"
      click_button "Import"
    end

    expect(page).to have_text("Importing… the recipe will wait in your Draft box.")
    expect(user.drafts.sole.source_text).to be_nil
  end

  it "shows a problem on the import page" do
    within("dialog[open]") do
      fill_in "Recipe link", with: "ftp://example.com/apple-cake"
      click_button "Import"
    end

    expect(page).to have_text("That doesn't look like a web link")
    expect(page).to have_css("h2", text: "Bring in a recipe")
  end

  it "leaves the pop-up for the recipe or the Draft box a link was already imported to" do
    recipe = create(:recipe, user: user, source_url: "https://example.com/apple-cake")
    user.drafts.create!(source_url: "https://example.com/pear-tart")

    within("dialog[open]") do
      fill_in "Recipe link", with: "https://example.com/apple-cake"
      click_button "Import"
    end
    click_link "View it"
    expect(page).to have_current_path(recipe_path(recipe))

    visit new_import_path
    fill_in "Recipe link", with: "https://example.com/pear-tart"
    click_button "Import"
    click_link "Open Draft box"
    expect(page).to have_current_path(drafts_path)
  end

  it "opens as new again after Cancel" do
    within("dialog[open]") do
      fill_in "Recipe link", with: "https://example.com/apple-cake"
      choose "Text", allow_label_click: true
      expect(page).to have_field("Recipe text")
      click_link "Cancel"
    end

    click_link "Import recipe"
    within("dialog[open]") do
      expect(page).to have_field("Recipe link", with: "")
      expect(page).to have_checked_field("Link")
      expect(page).to have_no_field("Recipe text")
    end
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
