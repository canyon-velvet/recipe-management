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
    expect(page.all(".draft-title").map(&:text).first).to eq "Soup" # newest first, titled from its link

    expect(row("Apple cake")).to have_css(".draft-icon--ready")
    expect(row("Apple cake")).to have_link("Review")
    expect(row("xiaohongshu")).to have_text("The site blocked automatic reading")
    expect(row("xiaohongshu")).to have_link("Paste text instead")
    expect(row("Soup")).to have_css(".draft-icon--reading")
    expect(row("Soup")).to have_no_link("Review")
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
