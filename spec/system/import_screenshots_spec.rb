require "rails_helper"

RSpec.describe "Importing from screenshots", type: :system do
  let(:user) { create(:user) }

  before do
    allow(CleanRecipeService).to receive(:available?).and_return(true)
    log_in_as user
    visit recipes_path
    click_link "Import recipe"
  end

  def screenshot(name) = Rails.root.join("spec/fixtures/files", name)

  it "shrinks the screenshots on the phone, shows them to remove or add to, and imports them under the name given" do
    within("dialog[open]") do
      choose "Screenshot", allow_label_click: true
      expect(page).to have_no_field("Recipe link")
      fill_in "Recipe name", with: "奶油烤鸡"
      attach_file "Choose screenshots", [ screenshot("tall_screenshot.png"), screenshot("small_screenshot.png") ],
                  make_visible: true
      expect(page).to have_css(".import-shot", count: 2)

      click_button "Remove screenshot 2"
      expect(page).to have_css(".import-shot", count: 1)
      attach_file "Add more", screenshot("small_screenshot.png"), make_visible: true
      expect(page).to have_css(".import-shot", count: 2)

      click_button "Import"
    end

    expect(page).to have_text("Importing… the recipe will wait in your Draft box.")
    expect(page).to have_css(".draft-row", text: /奶油烤鸡.*2 screenshots/m)
    draft = user.drafts.sole
    expect(draft.images.map(&:content_type)).to eq %w[image/jpeg image/jpeg]
    # The tall one is 1179 × 2556: shrunk to 1600 on its long side. The small one keeps its size.
    expect(draft.images.map { jpeg_size(_1.data) }).to eq [ [ 738, 1600 ], [ 300, 500 ] ]
  end

  it "asks for the name before sending" do
    within("dialog[open]") do
      choose "Screenshot", allow_label_click: true
      attach_file "Choose screenshots", screenshot("small_screenshot.png"), make_visible: true
      click_button "Import"

      expect(page).to have_css(".import-shot", count: 1) # still here, not sent
    end
    expect(user.drafts).to be_empty
  end

  # A JPEG's width and height, from its start-of-frame marker
  def jpeg_size(data)
    offset = 2
    loop do
      marker, length = data.byteslice(offset, 4).unpack("xCn")
      return data.byteslice(offset + 5, 4).unpack("nn").reverse if (0xC0..0xC3).cover?(marker)

      offset += 2 + length
    end
  end
end
