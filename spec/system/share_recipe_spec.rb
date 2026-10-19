require "rails_helper"

RSpec.describe "Sharing a recipe", type: :system do
  let(:user) { create(:user) }
  let!(:recipe) { create(:recipe, user: user, name: "Mapo tofu") }

  before do
    page.driver.with_playwright_page { |pw| pw.context.grant_permissions(%w[clipboard-read clipboard-write]) }
    log_in_as user
  end

  it "shares from the recipe page, copies the link, and stops sharing" do
    visit recipe_path(recipe)
    click_link "Share"

    expect(page).to have_css("h1", text: "Share “Mapo tofu”")
    link = shared_recipe_url(recipe.reload.share_token, host: Capybara.current_session.server.host,
                                                        port: Capybara.current_session.server.port)
    expect(page).to have_field("Share link", with: link, readonly: true)
    click_button "Copy link"
    expect(page).to have_button("Copied")

    visit link
    expect(page).to have_css("h1", text: "Mapo tofu")
    expect(page).to have_no_link("Edit")

    visit recipe_share_path(recipe)
    click_button "Stop sharing"
    expect(page).to have_text("Stopped sharing. The link no longer works.")
    expect(recipe.reload.share_token).to be_nil
  end

  it "shares from a card's menu on the recipe list" do
    visit recipes_path
    within(".recipe-card", text: "Mapo tofu") do
      click_button "More actions"
      click_link "Share"
    end

    expect(page).to have_css("h1", text: "Share “Mapo tofu”")
    expect(recipe.reload.share_token).to be_present
  end
end
