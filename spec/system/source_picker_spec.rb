require "rails_helper"

RSpec.describe "Picking a recipe's source", type: :system do
  let(:user) { create(:user) }
  let!(:xiaohongshu) { create(:source, user: user, name: "小红书") }
  let!(:douyin) { create(:source, user: user, name: "抖音") }
  let!(:mom) { create(:source, user: user, name: "Mom") }
  let(:recipe) { create(:recipe, user: user, source: xiaohongshu, name: "奶油烤鸡") }

  before do
    # The most-used sources come first: 抖音 has the most recipes, then 小红书 (with the recipe), then Mom
    create_list(:recipe, 2, user: user, source: douyin)
    recipe
    log_in_as user
  end

  def chips = all(".source-chip").map(&:text).map(&:squish)

  it "shows the most-used sources as chips, with the recipe's own checked, and saves the one tapped" do
    visit edit_recipe_path(recipe)

    expect(chips).to eq [ "抖音", "小红书", "Mom", "Other…" ]
    expect(page).to have_checked_field("小红书", visible: :all)

    choose "抖音", allow_label_click: true
    click_button "Update recipe"

    expect(page).to have_text("Recipe updated.")
    expect(recipe.reload.source).to eq douyin
  end

  it "unticks the source when its chip is tapped again, and won't save until one is picked" do
    visit edit_recipe_path(recipe)

    find(".source-chip", text: "小红书").click
    expect(page).to have_no_checked_field(visible: :all, name: "recipe[source_id]")

    click_button "Update recipe"
    message = page.evaluate_script("document.querySelector('[name=\"recipe[source_id]\"]').validationMessage")
    expect(message).to eq "Pick a source: tap one, or use Other… to find or create one."
    expect(page).to have_current_path(edit_recipe_path(recipe)) # not sent

    find(".source-chip", text: "Mom").click
    click_button "Update recipe"
    expect(page).to have_text("Recipe updated.")
    expect(recipe.reload.source).to eq mom
  end

  it "unticks the source with Space, as with a tap, also when the key is held down" do
    visit edit_recipe_path(recipe)

    find_field("小红书", visible: :all).send_keys(:space)
    expect(page).to have_no_checked_field(visible: :all, name: "recipe[source_id]")

    find_field("小红书", visible: :all).send_keys(:space) # ticked again
    expect(page).to have_checked_field("小红书", visible: :all)
    page.driver.with_playwright_page do |pw| # held: the key repeats before it's let go
      3.times { pw.keyboard.down(" ") }
      pw.keyboard.up(" ")
    end
    expect(page).to have_no_checked_field(visible: :all, name: "recipe[source_id]")
  end

  it "drops a draft's new source when its chip is unticked" do
    draft = user.drafts.create!(status: :ready, data: { "name" => "Mapo tofu", "source_name" => "Just One Cookbook",
                                                        "steps" => [ "Cook it." ] })
    visit new_recipe_path(draft_id: draft.id)

    find(".source-chip", text: "Just One Cookbook").click
    expect(page).to have_no_checked_field(visible: :all, name: "recipe[source_id]")
    expect(page.evaluate_script("document.querySelector('[name=\"recipe[new_source_name]\"]').disabled")).to be true

    find(".source-chip", text: "Just One Cookbook").click # and back
    expect(page).to have_checked_field("Just One Cookbook New", visible: :all)
    click_button "Create recipe"
    expect(page).to have_text("Recipe saved from your Draft box.")
    expect(user.recipes.find_by(name: "Mapo tofu").source.name).to eq "Just One Cookbook"
  end

  it "finds another source under Other…, which joins the chips checked" do
    cookbook = create(:source, user: user, name: "The Food Lab")
    5.times { create(:source, user: user) } # more sources than the chips show
    visit edit_recipe_path(recipe)
    expect(chips).not_to include("The Food Lab")

    click_button "Other…"
    fill_in "Search sources...", with: "Food"
    find(".autocomplete-item", text: "The Food Lab").click

    expect(page).to have_checked_field("The Food Lab", visible: :all)
    expect(page).to have_no_field("Search sources...")
    find(".source-chip", text: "The Food Lab").click # unticked, as the chips already there
    expect(page).to have_no_checked_field(visible: :all, name: "recipe[source_id]")
    find(".source-chip", text: "The Food Lab").click
    click_button "Update recipe"

    expect(page).to have_text("Recipe updated.")
    expect(recipe.reload.source).to eq cookbook
  end

  it "creates a new source under Other…" do
    visit edit_recipe_path(recipe)

    click_button "Other…"
    fill_in "Search sources...", with: "Grandma"
    find(".autocomplete-item--create").click
    within("dialog[open]") do
      expect(page).to have_field("Name", with: "Grandma")
      click_button "Save"
    end

    expect(page).to have_checked_field("Grandma", visible: :all)
    click_button "Update recipe"
    expect(page).to have_text("Recipe updated.")
    expect(recipe.reload.source.name).to eq "Grandma"
  end

  it "shows a draft's source you don't have yet as a new chip, created when saved, or dropped for another" do
    draft = user.drafts.create!(status: :ready, data: { "name" => "Mapo tofu", "source_name" => "Just One Cookbook",
                                                        "steps" => [ "Cook it." ] })

    visit new_recipe_path(draft_id: draft.id)
    expect(page).to have_checked_field("Just One Cookbook New", visible: :all)
    click_button "Create recipe"
    expect(page).to have_text("Recipe saved")
    expect(user.recipes.find_by(name: "Mapo tofu").source.name).to eq "Just One Cookbook"

    other = user.drafts.create!(status: :ready, data: { "name" => "Apple cake", "source_name" => "Some blog",
                                                        "steps" => [ "Bake it." ] })
    visit new_recipe_path(draft_id: other.id)
    choose "Mom", allow_label_click: true
    click_button "Create recipe"
    expect(page).to have_text("Recipe saved")
    expect(user.recipes.find_by(name: "Apple cake").source).to eq mom
    expect(user.sources.named("Some blog")).to be_empty
  end

  it "shows a draft's new source once when the form comes back with a problem" do
    draft = user.drafts.create!(status: :ready, data: { "name" => "Mapo tofu", "source_name" => "Just One Cookbook",
                                                        "steps" => [ "Cook it." ] })
    visit new_recipe_path(draft_id: draft.id)
    fill_in "Name", with: ""
    page.execute_script("document.querySelector('form.recipe-form').noValidate = true")
    click_button "Create recipe"

    expect(page).to have_css(".form-errors")
    expect(chips.count { _1.start_with?("Just One Cookbook") }).to eq 1
    expect(page).to have_checked_field("Just One Cookbook New", visible: :all)
  end
end
