require "rails_helper"

RSpec.describe Assistant::Tools::ImportRecipe do
  let(:user) { create(:user) }
  let(:link) { "https://example.com/mapo-tofu" }
  let(:turn) { Assistant::Turn.new("Can you import #{link}, please?") }
  let(:tool) { described_class.new(user, turn) }

  it "starts importing a link from the user's message into their Draft box" do
    result = nil
    expect { result = tool.call({ url: link }) }.to have_enqueued_job(ImportRecipeJob)

    expect(result).to include(result: "started", draft: include(status: "reading"))
    expect(user.drafts.sole).to have_attributes(source_url: link, status: "reading")
    expect(turn.draft_ids).to eq [ user.drafts.sole.id ] # shown as a card under the reply
  end

  it "imports the link the user wrote, without the punctuation after it, even if Claude passes that along" do
    tool = described_class.new(user, Assistant::Turn.new("Import #{link}. Thanks!"))

    expect(tool.call({ url: "#{link}." })).to include(result: "started")
    expect(user.drafts.sole.source_url).to eq link
  end

  it "shares the hourly import limit with the import form, and says so" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    stub_const("StartImportService::HOURLY_LIMIT", 1)
    StartImportService.new(user: user, url: "https://example.com/from-the-form").call

    expect(tool.call({ url: link }))
      .to eq(result: "not_started", reason: I18n.t("imports.errors.rate_limited"))
    expect(user.drafts.where(source_url: link)).to be_empty
  end

  it "only imports links the user sent" do
    expect(tool.call({ url: "https://example.com/somewhere-else" }))
      .to eq(error: "Only links in the user's latest message can be imported.")
    expect(user.drafts).to be_empty
  end

  it "says when the link is already a saved recipe, so it can be shown as a card" do
    recipe = create(:recipe, user: user, name: "Mapo tofu", source_url: link)

    expect(tool.call({ url: link })).to eq(result: "already_saved", recipe: { id: recipe.id, name: "Mapo tofu" })
    expect(turn.found?(recipe.id)).to be true

    # Also when the user's sentence ends right after the link
    tool = described_class.new(user, Assistant::Turn.new("Again: #{link}."))
    expect(tool.call({ url: "#{link}." })).to include(result: "already_saved")
  end

  it "says when the link is already in the Draft box, and how it's going" do
    draft = user.drafts.create!(source_url: link, status: :ready, data: { "name" => "Mapo tofu" })

    expect(tool.call({ url: link }))
      .to include(result: "already_in_draft_box", draft: include(title: "Mapo tofu", status: "ready"))
    expect(turn.draft_ids).to eq [ draft.id ]
  end

  it "reads a link that failed before again" do
    user.drafts.create!(source_url: link, status: :failed, failure_reason: "fetch_failed")

    expect(tool.call({ url: link })).to include(result: "started", draft: include(status: "reading"))
  end

  it "explains why a link can't be imported" do
    refused = StartImportService::Result.new(draft: nil, error: :invalid_link, recipe: nil)
    allow(StartImportService).to receive(:new).and_return(instance_double(StartImportService, call: refused))

    expect(tool.call({ url: link }))
      .to eq(result: "not_started", reason: "That doesn't look like a web link (http or https).")
  end

  it "starts at most a few imports per reply, not counting links it didn't need to import" do
    saved = create(:recipe, user: user, source_url: "https://example.com/saved")
    links = [ saved.source_url, *(1..4).map { |i| "https://example.com/recipe-#{i}" } ]
    tool = described_class.new(user, Assistant::Turn.new("Import these: #{links.join(' ')}"))

    results = links.map { |url| tool.call({ url: url }) }

    expect(results.first).to include(result: "already_saved")
    expect(results[1..3]).to all(include(result: "started"))
    expect(results.last).to eq(error: "You can import at most 3 links per reply.")
    expect(user.drafts.count).to eq 3
  end
end
