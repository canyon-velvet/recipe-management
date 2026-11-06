require "rails_helper"

RSpec.describe "Creating a tag from the recipe form", type: :system do
  let(:user) { create(:user) }
  let(:recipe) { create(:recipe, user: user) }

  def tag_box = find(".tag-select .ts-control")

  def open_create_tag(name)
    tag_box.click
    tag_box.find("input").send_keys(name)
    expect(page).to have_no_css(".ts-dropdown .no-results") # Create tag says it
    find(".ts-dropdown .create", text: "Create tag “#{name}”").click
    expect(page).to have_css("dialog[open]", text: "New tag")
  end

  before do
    create(:tag, key: "dinner", kind: "meal")
    log_in_as user
    visit edit_recipe_path(recipe)
  end

  it "fills in the typed name, takes a group, and adds the tag to the recipe's" do
    open_create_tag("Korean")

    within("dialog[open]") do
      expect(page).to have_field("Name", with: "Korean")
      expect(page).to have_checked_field("Other", visible: :all)
      choose "Cuisine", allow_label_click: true
      click_button "Save"
    end

    expect(page).to have_no_css("dialog[open]")
    expect(tag_box).to have_css(".item", text: /\AKorean\b/) # its name alone, then ×
    expect(user.tags.sole).to have_attributes(name: "Korean", kind: "cuisine")

    click_button "Update recipe"
    expect(page).to have_current_path(recipe_path(recipe))
    expect(recipe.reload.tags.map(&:name)).to eq [ "Korean" ]
  end

  it "offers to create only a tag that isn't there, and takes a comma as part of the name" do
    tag_box.click
    tag_box.find("input").send_keys("dinner")
    expect(page).to have_css(".ts-dropdown .option .highlight", text: "Dinner") # the list as searched
    expect(page).to have_no_css(".ts-dropdown .create")

    tag_box.find("input").send_keys(:backspace, :backspace, :backspace, :backspace, :backspace, :backspace,
                                    "Quick, easy")
    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_css(".ts-dropdown .create", text: "Create tag “Quick, easy”")
  end

  it "opens on Enter, and saves on Enter without saving the recipe" do
    tag_box.click
    tag_box.find("input").send_keys("Korean")
    expect(page).to have_css(".ts-dropdown .create.active", text: "Create tag “Korean”")
    tag_box.find("input").send_keys(:enter)
    expect(page).to have_css("dialog[open]", text: "New tag")

    find_field("Name", with: "Korean").send_keys(:enter)

    expect(page).to have_no_css("dialog[open]")
    expect(tag_box).to have_css(".item", text: "Korean")
    expect(page).to have_current_path(edit_recipe_path(recipe))
  end

  it "says why it couldn't, and keeps the pop-up open" do
    open_create_tag("晚餐") # Dinner, in Chinese

    within("dialog[open]") do
      click_button "Save"
      expect(page).to have_text("Name has already been taken")
    end
    expect(user.tags).to be_empty
  end

  it "adds nothing when the pop-up is cancelled, and starts afresh the next time" do
    open_create_tag("Korean")
    within("dialog[open]") do
      choose "Cuisine", allow_label_click: true
      click_button "Cancel"
    end

    expect(page).to have_no_css("dialog[open]")
    expect(tag_box).to have_no_css(".item")
    expect(user.tags).to be_empty

    open_create_tag("Thai")
    within("dialog[open]") do
      expect(page).to have_field("Name", with: "Thai")
      expect(page).to have_checked_field("Other", visible: :all)
      expect(page).to have_no_field("Emoji") # tags have none: a recipe has its own icon
    end
  end
end
