require "rails_helper"

RSpec.describe "Sharing a recipe", type: :system do
  let(:user) { create(:user) }
  let!(:recipe) { create(:recipe, user: user, name: "Mapo tofu") }

  before do
    page.driver.with_playwright_page { |pw| pw.context.grant_permissions(%w[clipboard-read clipboard-write]) }
    log_in_as user
  end

  it "shares from the recipe page in a pop-up, copies the link, cancels, and stops sharing" do
    visit recipe_path(recipe)
    click_link "Share"

    expect(page).to have_css("dialog[open] h2", text: "Share “Mapo tofu”")
    link = shared_recipe_url(recipe.reload.share_token, host: Capybara.current_session.server.host,
                                                        port: Capybara.current_session.server.port)
    within("dialog[open]") do
      expect(page).to have_field("Share link", with: link, readonly: true)
      click_button "Copy link"
      expect(page).to have_button("Copied")
      click_link "Cancel"
    end
    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_current_path(recipe_path(recipe))

    visit link
    expect(page).to have_css("h1", text: "Mapo tofu")
    expect(page).to have_no_link("Edit")

    visit recipe_path(recipe)
    click_link "Share"
    within("dialog[open]") do
      expect(page).to have_css(".share-footer button.btn-pill-danger", text: "Stop sharing")
      click_button "Stop sharing"
    end
    expect(page).to have_text("Stopped sharing. The link no longer works.")
    expect(page).to have_current_path(recipe_path(recipe))
    expect(recipe.reload.share_token).to be_nil
  end

  it "shares from a card's menu on the recipe list, in a pop-up over the list" do
    other = create(:recipe, user: user, name: "Apple cake")
    visit recipes_path
    within(".recipe-card", text: "Mapo tofu") do
      click_button "More actions"
      click_link "Share"
    end

    within("dialog[open]") do
      expect(page).to have_css("h2", text: "Share “Mapo tofu”")
      click_button "Close"
    end
    expect(page).to have_current_path(recipes_path)
    expect(recipe.reload.share_token).to be_present

    # The pop-up shows each card's own link
    within(".recipe-card", text: "Apple cake") do
      click_button "More actions"
      click_link "Share"
    end
    within("dialog[open]") do
      expect(page).to have_css("h2", text: "Share “Apple cake”")
      expect(page).to have_field("Share link", with: /#{other.reload.share_token}\z/)
      click_button "Stop sharing"
    end
    expect(page).to have_text("Stopped sharing. The link no longer works.")
    expect(page).to have_current_path(recipes_path)
  end
end
