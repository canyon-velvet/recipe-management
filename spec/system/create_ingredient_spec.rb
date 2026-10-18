require "rails_helper"

RSpec.describe "Creating an ingredient from the recipe form", type: :system do
  let(:user) { create(:user) } # with the default aisles
  let(:recipe) { create(:recipe, user: user) }

  def open_create_ingredient(name)
    all(:field, placeholder: "Search ingredients...").last.fill_in(with: name)
    find(".autocomplete-item--create", text: "Create ingredient").click
    expect(page).to have_css("dialog[open]", text: "Create ingredient")
  end

  def aisle_box = find(".aisle-combobox .ts-control") # inside the open pop-up

  before do
    log_in_as user
    visit edit_recipe_path(recipe)
  end

  it "fills in the typed name, finds the aisle as you type, and saves on Enter without saving the recipe" do
    open_create_ingredient("sausage")

    within("dialog[open]") do
      expect(page).to have_field("Name", with: "sausage")
      expect(page.evaluate_script("document.activeElement.id")).to eq "new_ingredient_name"
      aisle_box.click
      aisle_box.find("input").send_keys("meat", :enter) # at once: the list is already narrowed to Meat & Seafood
      expect(aisle_box).to have_css(".item", text: "Meat & Seafood")
      aisle_box.find("input").send_keys(:enter) # saves the pop-up, not the recipe form behind it
    end

    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_current_path(edit_recipe_path(recipe))
    expect(page).to have_field(placeholder: "Search ingredients...", with: "sausage")
    expect(user.ingredients.find_by!(name: "sausage").aisle.key).to eq "meat_seafood"
  end

  it "doesn't save on the Enter that finishes typing Chinese (Pinyin) in Safari" do
    open_create_ingredient("doufu")

    # Safari ends the input method's composition with this Enter (keyCode 229). Saving would cancel it at once.
    saved = !page.evaluate_script(<<~JS)
      document.getElementById("new_ingredient_name").dispatchEvent(
        new KeyboardEvent("keydown", { key: "Enter", keyCode: 229, bubbles: true, cancelable: true }))
    JS

    expect(saved).to be false
    expect(page).to have_css("dialog[open]", text: "Create ingredient")
  end

  it "adds the typed aisle when there isn't one, just before Other, and offers it next time" do
    open_create_ingredient("pretzels")

    within("dialog[open]") do
      aisle_box.click
      aisle_box.find("input").send_keys("Snacks")
      find(".ts-dropdown .create", text: "＋ Add Snacks").click
      expect(aisle_box).to have_css(".item", text: "Snacks")
      click_button "Save"
    end

    expect(page).to have_no_css("dialog[open]")
    expect(user.ingredients.find_by!(name: "pretzels").aisle.name).to eq "Snacks"
    expect(user.aisles.ordered.last(2).map(&:name)).to eq [ "Snacks", "Other" ]

    click_button "+ Add ingredient"
    open_create_ingredient("crisps")
    within("dialog[open]") do
      aisle_box.click
      aisle_box.find("input").send_keys("snacks")
      expect(page).to have_css(".ts-dropdown .option", exact_text: "Snacks")
      expect(page).to have_no_css(".ts-dropdown .create") # it has that name already
    end
  end

  it "starts empty again after it's closed" do
    open_create_ingredient("sausage")
    within("dialog[open]") do
      aisle_box.click
      aisle_box.find("input").send_keys("meat")
      expect(page).to have_no_css(".ts-dropdown .option", text: "Produce")
      find(".ts-dropdown .option", text: "Meat & Seafood").click
      click_button "Close"
    end

    open_create_ingredient("pretzels")
    within("dialog[open]") { expect(aisle_box).to have_no_css(".item") }
  end
end
