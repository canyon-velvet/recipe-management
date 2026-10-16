require "rails_helper"

RSpec.describe "The recipe page", type: :system do
  it "shows tips typed into the description in their own section after the method" do
    user = create(:user)
    recipe = create(:recipe, user: user, name: "Mapo tofu")
    log_in_as user

    visit edit_recipe_path(recipe)
    fill_in "Description", with: "Silky tofu.\n\n**Tips**\n\n- Cut gently."
    click_button "Update recipe"

    expect(page).to have_css("h1", text: "Mapo tofu")
    expect(page).to have_css(".recipe-description", text: "Silky tofu.")
    expect(page).to have_no_css(".recipe-description", text: "Cut gently")
    expect(page.all(".recipe-section-heading").map(&:text)).to eq %w[METHOD TIPS]
    expect(page).to have_css(".recipe-tips", text: "Cut gently.")
  end
end
