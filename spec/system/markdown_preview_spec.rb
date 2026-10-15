require "rails_helper"

RSpec.describe "Previewing markdown", type: :system do
  let(:user) { create(:user) }

  it "shows the description as it will be saved, without running HTML in it" do
    log_in_as user
    visit new_recipe_path

    fill_in "Description", with: %(**Bold** <img src="x" onerror="document.title='hacked'">)
    click_button "Preview"

    preview = "[data-markdown-preview-target='preview']"
    expect(page).to have_css("#{preview} strong", text: "Bold")
    expect(page).to have_no_css("#{preview} img")
    expect(page).to have_no_title("hacked")
  end
end
