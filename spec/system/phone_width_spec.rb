require "rails_helper"

RSpec.describe "Long words on a phone", type: :system do
  let(:user) { create(:user) }
  let(:link) { "https://www.xiachufang.com/recipe/107465012/?utm_source=share_link&utm_medium=ios_app_share" }

  before do
    allow(CleanRecipeService).to receive(:available?).and_return(true)
    page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: 390, height: 844) }
  end

  def overflow(selector) = page.evaluate_script("(e => e.scrollWidth - e.clientWidth)(document.querySelector('#{selector}'))")

  it "wraps a long link in the assistant's chat instead of widening it" do
    conversation = user.current_conversation!
    conversation.messages.create!(role: :user, content: "Import #{link}")
    conversation.messages.create!(role: :assistant, agent: :import, content: "Importing #{link} and `a_long_word_with_no_spaces_at_all`")
    log_in_as user
    click_button "Open assistant"

    expect(page).to have_css(".assistant-message--assistant", text: "Importing")
    expect(overflow(".assistant-messages")).to eq 0
  end

  it "wraps a long link in a recipe instead of widening the page" do
    recipe = create(:recipe, user: user, description: "From #{link}")
    log_in_as user

    visit recipe_path(recipe)

    expect(page).to have_text("From")
    expect(overflow("html")).to eq 0
  end
end
