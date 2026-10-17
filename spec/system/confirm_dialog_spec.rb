require "rails_helper"

RSpec.describe "Confirming a delete", type: :system do
  let(:user) { create(:user) }
  let!(:recipe) { create(:recipe, user: user, name: "Mapo tofu") }

  def open_delete
    visit recipe_path(recipe)
    within(".recipe-heading-actions") { click_link "Delete" }
  end

  it "asks in the app's own pop-up, and deletes on Delete" do
    log_in_as user
    open_delete

    within("dialog[open]") do
      expect(page).to have_text("Delete this recipe?")
      click_button "Delete"
    end

    expect(page).to have_text("Recipe deleted.")
    expect(user.recipes).to be_empty
  end

  it "asks for a delete button inside another pop-up (an aisle in Edit aisles)" do
    log_in_as user
    find(".account-toggle").click
    click_button "Edit aisles"

    within("dialog[open]", text: "Edit aisles") { click_button "Delete Bakery" }
    within("dialog[open]", text: "Delete \"Bakery\"?") { click_button "Delete" }

    within("dialog[open]", text: "Edit aisles") { expect(page).to have_no_field(with: "Bakery") }
    expect(user.aisles.where(key: "bakery")).to be_empty
  end

  it "keeps it on Cancel, or Esc" do
    log_in_as user

    open_delete
    within("dialog[open]") { click_button "Cancel" }
    expect(page).to have_no_css("dialog[open]")

    open_delete
    find("dialog[open]").send_keys(:escape)
    expect(page).to have_no_css("dialog[open]")

    expect(page).to have_current_path(recipe_path(recipe))
    expect(recipe.reload).to be_persisted
  end
end
