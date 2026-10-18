require "rails_helper"

RSpec.describe Draft do
  describe "its cards in the assistant's chat" do
    let(:user) { create(:user) }
    let(:draft) { user.drafts.create!(source_url: "https://example.com/mapo-tofu") }

    before { allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to) }

    it "follows the import as it's read" do
      draft.update!(status: :ready, data: { "name" => "Mapo tofu" })

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        [ user, :assistant ], targets: ".assistant-draft-#{draft.id}",
                              partial: "assistant/messages/draft_card", locals: { draft: draft }
      )
    end

    it "goes once the draft is saved or discarded" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to)

      draft.destroy!

      expect(Turbo::StreamsChannel).to have_received(:broadcast_remove_to)
        .with([ user, :assistant ], targets: ".assistant-draft-#{draft.id}")
    end
  end

  it "names why it failed by a reason the app can say, else the generic one" do
    expect(Draft.new(failure_reason: "fetch_failed").failure_reason_key).to eq "fetch_failed"
    expect(Draft.new(failure_reason: "unexpected").failure_reason_key).to eq "generic" # an error nobody foresaw
    expect(Draft.new(failure_reason: nil).failure_reason_key).to eq "generic"
  end

  it "takes pasted text up to the length of a page's text" do
    draft = build(:user).drafts.build(source_text: "a" * Draft::MAX_SOURCE_TEXT)
    expect(draft).to be_valid

    draft.source_text += "a"
    expect(draft).not_to be_valid
    expect(draft.errors.of_kind?(:source_text, :too_long)).to be true
  end
end
