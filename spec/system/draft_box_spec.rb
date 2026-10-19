require "rails_helper"

RSpec.describe "The Draft box", type: :system do
  let(:user) { create(:user) }

  before do
    user.drafts.create!(source_url: "https://example.com/apple-cake", status: :ready, data: { "name" => "Apple cake" })
    user.drafts.create!(source_url: "https://www.xiaohongshu.com/explore/1", status: :failed, failure_reason: "blocked")
    user.drafts.create!(source_url: "https://example.com/soup")
    log_in_as user
    visit drafts_path
  end

  def row(text) = find(".draft-row", text: text)

  it "shows each draft as a row with where it's at and what can be done with it" do
    expect(page).to have_css("h1", text: "Draft box")
    expect(page.all(".draft-row .status-title").map(&:text).first).to eq "Soup" # newest first, titled from its link

    expect(row("Apple cake")).to have_css(".draft-icon--ready")
    expect(row("Apple cake")).to have_link("Review")
    expect(row("xiaohongshu")).to have_text("The site blocked automatic reading")
    expect(row("xiaohongshu")).to have_link("Paste text instead")
    expect(row("Soup")).to have_css(".draft-icon--reading")
    expect(row("Soup")).to have_no_link("Review")
  end

  it "opens Text for a blocked link, from its site, and reads the pasted text into the same draft" do
    allow(CleanRecipeService).to receive(:available?).and_return(true)
    within(row("xiaohongshu")) { click_link "Paste text instead" }

    expect(page).to have_checked_field("Text")
    expect(page).to have_checked_field("小红书 New", visible: :all) # its site, a source the user doesn't have yet
    expect(page).to have_field("Recipe text", focused: true)
    fill_in "Recipe text", with: "红烧肉\n五花肉 500克"
    click_button "Import"

    expect(page).to have_text("Importing… the recipe will wait in your Draft box.")
    draft = user.drafts.find_by(source_url: "https://www.xiaohongshu.com/explore/1")
    expect(draft).to have_attributes(status: "reading", source_text: "红烧肉\n五花肉 500克",
                                     data: { "source_name" => "小红书" })
  end

  it "tries a failed import again, beside pasting the text instead" do
    expect(row("Apple cake")).to have_no_button("Try again")

    within(row("xiaohongshu")) do
      expect(page.all("a, button").map(&:text)).to eq [ "Try again", "Paste text instead", "Discard" ]
      click_button "Try again"
    end

    expect(row("xiaohongshu")).to have_css(".draft-icon--reading")
    expect(row("xiaohongshu")).to have_no_text("The site blocked automatic reading")
  end

  it "discards a draft after asking" do
    within(row("Apple cake")) { click_button "Discard" }
    within("dialog[open]") { click_button "Delete" }

    expect(page).to have_text("Draft discarded.")
    expect(page).to have_no_css(".draft-row", text: "Apple cake")
  end

  it "opens the import pop-up" do
    click_link "Import recipe"

    within("dialog[open]") { expect(page).to have_css("h2", text: "Bring in a recipe") }
  end
end
