require "rails_helper"

RSpec.describe StartImportService do
  let(:user) { create(:user) }

  # The test env's cache stores nothing; the hourly limit needs one that counts.
  before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

  def start(url: nil, text: nil) = described_class.new(user: user, url: url, text: text).call

  def screenshot(name = "small_screenshot.png", type: "image/png")
    Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files", name), type)
  end

  describe "from screenshots" do
    before { allow(CleanRecipeService).to receive(:available?).and_return(true) }

    def start_from(screenshots, title: "奶油烤鸡") = described_class.new(user: user, title: title, screenshots: screenshots).call

    it "puts a Reading… draft with the user's name for it, holding the screenshots in order, and counts one import" do
      result = nil
      expect { result = start_from([ screenshot, screenshot("tall_screenshot.png") ]) }.to have_enqueued_job(ImportRecipeJob)

      expect(result).to be_success
      expect(result.draft).to have_attributes(status: "reading", title: "奶油烤鸡", screenshot_count: 2, source_url: nil)
      expect(result.draft.images.map(&:position)).to eq [ 1, 2 ]
      expect(result.draft.images.first).to have_attributes(content_type: "image/png",
                                                           data: File.binread(screenshot.path))
      expect(described_class.imports_left(user)).to eq described_class::HOURLY_LIMIT - 1
    end

    it "needs a name, to tell which recipe the screenshots are of" do
      expect(start_from([ screenshot ], title: "  ").error).to eq :title_blank
      expect(user.drafts).to be_empty
      expect(described_class.imports_left(user)).to eq described_class::HOURLY_LIMIT
    end

    it "takes up to #{Draft::MAX_SCREENSHOTS} screenshots" do
      expect(start_from(Array.new(Draft::MAX_SCREENSHOTS + 1) { screenshot }).error).to eq :too_many_screenshots
      expect(start_from(Array.new(Draft::MAX_SCREENSHOTS) { screenshot })).to be_success
    end

    it "refuses a file that isn't a picture Claude reads, whatever the browser called it" do
      not_a_picture = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 …"), "image/png", original_filename: "a.png")

      expect(start_from([ screenshot, not_a_picture ]).error).to eq :unreadable_screenshot
      expect(Draft.where(user: user)).to be_empty
    end

    it "needs Claude to read them" do
      allow(CleanRecipeService).to receive(:available?).and_return(false)

      expect(start_from([ screenshot ]).error).to eq :needs_claude
    end
  end

  it "puts a Reading… draft in the Draft box and reads it in the background" do
    result = nil
    expect { result = start(url: "https://example.com/soup") }.to have_enqueued_job(ImportRecipeJob)

    expect(result).to be_success
    expect(result.draft).to have_attributes(status: "reading", source_url: "https://example.com/soup")
  end

  it "starts #{described_class::HOURLY_LIMIT} imports an hour, then refuses more" do
    described_class::HOURLY_LIMIT.times { |i| expect(start(url: "https://example.com/#{i}")).to be_success }

    expect(start(url: "https://example.com/one-more").error).to eq :rate_limited
    expect(user.drafts.count).to eq described_class::HOURLY_LIMIT
  end

  it "lets an admin start #{described_class::ADMIN_HOURLY_LIMIT} imports an hour" do
    admin = create(:user, :admin)
    imports = Array.new(described_class::ADMIN_HOURLY_LIMIT) do |i|
      described_class.new(user: admin, url: "https://example.com/#{i}").call
    end

    expect(imports).to all(be_success)
    expect(described_class.new(user: admin, url: "https://example.com/one-more").call.error).to eq :rate_limited
    expect(described_class.imports_left(admin)).to eq 0
  end

  it "counts imports whose drafts were discarded, and failed drafts read again" do
    stub_const("StartImportService::HOURLY_LIMIT", 2)
    start(url: "https://example.com/discarded").draft.destroy!
    user.drafts.create!(source_url: "https://example.com/failed", status: :failed)

    expect(start(url: "https://example.com/failed")).to be_success
    expect(start(url: "https://example.com/third").error).to eq :rate_limited
  end

  describe "an import that fails before Claude reads it" do
    def read(draft) = ImportRecipeService.new(draft).call

    it "gives its count back, so discarding it costs nothing and pasting the text instead costs one" do
      draft = start(url: "https://www.xiachufang.com/recipe/1").draft
      expect(described_class.imports_left(user)).to eq described_class::HOURLY_LIMIT - 1

      # The site answers with a captcha page
      allow(FetchPageService).to receive(:new).and_raise(FetchPageService::Error.new(:blocked, "challenge page"))
      read(draft)

      expect(draft.reload.failure_reason).to eq "blocked"
      expect(described_class.imports_left(user)).to eq described_class::HOURLY_LIMIT
      allow(CleanRecipeService).to receive(:available?).and_return(true) # pasted text needs Claude
      expect(start(url: "https://www.xiachufang.com/recipe/1", text: "红烧肉\n五花肉 500克\n炖一小时")).to be_success
      expect(described_class.imports_left(user)).to eq described_class::HOURLY_LIMIT - 1
    end

    it "keeps counting one Claude did read, which cost a call" do
      draft = start(url: "https://example.com/not-food").draft
      allow(FetchPageService).to receive(:new).and_return(instance_double(FetchPageService, call: "<html></html>"))
      allow(ExtractRecipeService).to receive(:new).and_return(instance_double(ExtractRecipeService, call: nil))
      allow(CleanRecipeService).to receive(:available?).and_return(true)
      allow(CleanRecipeService).to receive(:new).and_raise(CleanRecipeService::Error.new(:not_a_recipe))

      read(draft)

      expect(draft.reload.failure_reason).to eq "not_a_recipe"
      expect(described_class.imports_left(user)).to eq described_class::HOURLY_LIMIT - 1
    end
  end

  it "doesn't count what it refuses before starting" do
    stub_const("StartImportService::HOURLY_LIMIT", 1)

    expect(start(url: "not a link").error).to eq :invalid_link
    expect(start(url: "https://example.com/soup")).to be_success
  end

  it "refuses pasted text longer than a page's text, which would all be sent to Claude" do
    allow(CleanRecipeService).to receive(:available?).and_return(true)

    expect(start(text: "a" * (Draft::MAX_SOURCE_TEXT + 1)).error).to eq :too_long
    expect(start(text: "a" * Draft::MAX_SOURCE_TEXT)).to be_success
    expect(user.drafts.count).to eq 1
  end

  it "counts a line break as one character, as the paste box does, though browsers send two" do
    allow(CleanRecipeService).to receive(:available?).and_return(true)
    text = ("a" * 99 + "\r\n") * 200 # 20,000 characters in the box, 20,200 as sent

    expect(start(text: text)).to be_success
    expect(user.drafts.sole.source_text).not_to include("\r")
  end
end
