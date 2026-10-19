require "rails_helper"

RSpec.describe "Sharing a recipe", type: :system do
  let(:user) { create(:user) }
  let!(:recipe) { create(:recipe, user: user, name: "Mapo tofu") }

  before do
    page.driver.with_playwright_page { |pw| pw.context.grant_permissions(%w[clipboard-read clipboard-write]) }
    log_in_as user
  end

  it "shares from the recipe page in a pop-up, copies the link, which closes it, and stops sharing" do
    visit recipe_path(recipe)
    click_link "Share"

    expect(page).to have_css("dialog[open] h2", text: "Share “Mapo tofu”")
    link = shared_recipe_url(recipe.reload.share_token, host: Capybara.current_session.server.host,
                                                        port: Capybara.current_session.server.port)
    within("dialog[open]") do
      expect(page).to have_field("Share link", with: link, readonly: true)
      click_button "Copy link"
      expect(page).to have_button("Copied")
    end
    # It closes by itself a moment later, once "Copied" has shown
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

  it "closes once the phone's share sheet has shared the link, and stays open if it was dismissed" do
    # Headless Chromium has no share sheet: stand one in that shares, or is dismissed, as the test says
    page.driver.with_playwright_page do |pw|
      pw.add_init_script(script: <<~JS)
        navigator.share = (data) => {
          window.shared = data
          return window.dismissShare ? Promise.reject(new DOMException("", "AbortError")) : Promise.resolve()
        }
      JS
    end
    visit recipe_path(recipe)
    click_link "Share"

    page.execute_script("window.dismissShare = true")
    within("dialog[open]") { click_button "Share…" }
    expect(page.evaluate_script("window.shared.title")).to eq "Mapo tofu"
    expect(page).to have_css("dialog[open]")

    page.execute_script("window.dismissShare = false")
    within("dialog[open]") { click_button "Share…" }
    expect(page).to have_no_css("dialog[open]")
    expect(page.evaluate_script("window.shared.url")).to end_with "/r/#{recipe.reload.share_token}"
  end

  it "shares from a card's menu on the recipe list, in a pop-up over the list" do
    other = create(:recipe, user: user, name: "Apple cake")
    visit recipes_path
    within(".recipe-card", text: "Mapo tofu") do
      click_button "More actions"
      click_link "Share"
    end

    # Cancel closes the pop-up, leaving the list where it was (its link, to the recipe, is for the page of its own)
    within("dialog[open]") do
      expect(page).to have_css("h2", text: "Share “Mapo tofu”")
      click_link "Cancel"
    end
    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_current_path(recipes_path)
    expect(recipe.reload.share_token).to be_present

    # Copying closes the pop-up a moment later, but not one opened again in that moment, for another card
    within(".recipe-card", text: "Mapo tofu") do
      click_button "More actions"
      click_link "Share"
    end
    within("dialog[open]") do
      click_button "Copy link"
      expect(page).to have_button("Copied") # so the close is on its way
    end
    find("dialog[open]").send_keys(:escape)
    expect(page).to have_no_css("dialog[open]")

    # The pop-up shows each card's own link
    within(".recipe-card", text: "Apple cake") do
      click_button "More actions"
      click_link "Share"
    end
    within("dialog[open]") do
      expect(page).to have_css("h2", text: "Share “Apple cake”")
      sleep 1 # past the copy's close
      expect(page).to have_css("h2", text: "Share “Apple cake”", wait: 0)
      expect(page).to have_field("Share link", with: /#{other.reload.share_token}\z/)
      click_button "Stop sharing"
    end
    expect(page).to have_text("Stopped sharing. The link no longer works.")
    expect(page).to have_current_path(recipes_path)
  end
end
