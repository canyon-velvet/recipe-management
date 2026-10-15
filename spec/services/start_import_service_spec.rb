require "rails_helper"

RSpec.describe StartImportService do
  let(:user) { create(:user) }

  # The test env's cache stores nothing; the hourly limit needs one that counts.
  before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

  def start(url: nil, text: nil) = described_class.new(user: user, url: url, text: text).call

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

  it "counts imports whose drafts were discarded, and failed drafts read again" do
    stub_const("StartImportService::HOURLY_LIMIT", 2)
    start(url: "https://example.com/discarded").draft.destroy!
    user.drafts.create!(source_url: "https://example.com/failed", status: :failed)

    expect(start(url: "https://example.com/failed")).to be_success
    expect(start(url: "https://example.com/third").error).to eq :rate_limited
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
end
