require "rails_helper"

RSpec.describe ImportRecipeService do
  let(:user) { create(:user) }
  let(:draft) do
    user.drafts.create!(data: { "name" => "奶油烤鸡", "source_name" => "抖音" }, screenshot_count: 2, images: [
      DraftImage.new(position: 1, content_type: "image/png", data: "first"),
      DraftImage.new(position: 2, content_type: "image/jpeg", data: "second")
    ])
  end

  before { allow(CleanRecipeService).to receive(:available?).and_return(true) }

  describe "a draft from screenshots" do
    it "has Claude read the screenshots in order, keeps the user's name for it, then deletes them" do
      cleaner = instance_double(CleanRecipeService, call: { "name" => "Creamy roast chicken", "description" => "",
                                                            "ingredients" => [], "steps" => [ "Roast it." ] })
      expect(CleanRecipeService).to receive(:new)
        .with(user: user, recipe: nil, text: nil,
              images: [ { media_type: "image/png", data: "first" }, { media_type: "image/jpeg", data: "second" } ])
        .and_return(cleaner)
      expect(FetchPageService).not_to receive(:new)

      described_class.new(draft).call

      expect(draft.reload).to have_attributes(status: "ready", title: "奶油烤鸡", screenshot_count: 2)
      expect(draft.data["steps"]).to eq [ "Roast it." ]
      expect(draft.data["source_name"]).to eq "抖音" # where the user said it's from
      expect(DraftImage.where(draft: draft)).to be_empty
    end

    it "keeps the screenshots when they couldn't be read, so they can be tried again" do
      allow(CleanRecipeService).to receive(:new).and_raise(CleanRecipeService::Error.new(:not_a_recipe))

      described_class.new(draft).call

      expect(draft.reload).to have_attributes(status: "failed", failure_reason: "not_a_recipe", title: "奶油烤鸡")
      expect(draft.images.count).to eq 2
    end
  end

  it "keeps where pasted text is from, which Claude doesn't know" do
    text_draft = user.drafts.create!(source_text: "红烧肉\n五花肉 500克", data: { "source_name" => "Mom" })
    allow(CleanRecipeService).to receive(:new).and_return(
      instance_double(CleanRecipeService, call: { "name" => "红烧肉", "description" => "", "steps" => [ "炖。" ] })
    )

    described_class.new(text_draft).call

    expect(text_draft.reload.data).to include("name" => "红烧肉", "source_name" => "Mom")
  end

  it "deletes a draft's screenshots with it" do
    draft.destroy

    expect(DraftImage.count).to eq 0
  end
end
