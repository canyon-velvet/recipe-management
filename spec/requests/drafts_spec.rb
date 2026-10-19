require "rails_helper"

RSpec.describe "The Draft box", type: :request do
  let(:user) { create(:user) }

  before do
    allow(CleanRecipeService).to receive(:available?).and_return(true)
    log_in_as user
  end

  describe "trying a failed import again" do
    it "reads the same link again, in the same draft" do
      draft = user.drafts.create!(source_url: "https://www.xiachufang.com/recipe/1", status: :failed,
                                  failure_reason: :fetch_failed)

      expect { post retry_draft_path(draft) }.to have_enqueued_job(ImportRecipeJob).with(draft, "en")

      expect(response).to redirect_to(drafts_path)
      expect(draft.reload).to have_attributes(status: "reading", failure_reason: nil)
      expect(user.drafts.count).to eq 1
    end

    it "reads pasted text again, in the same draft" do
      draft = user.drafts.create!(source_text: "红烧肉\n五花肉 500克", status: :failed, failure_reason: :cleanup_failed)

      post retry_draft_path(draft)

      expect(draft.reload).to have_attributes(status: "reading", source_text: "红烧肉\n五花肉 500克")
      expect(user.drafts.count).to eq 1
    end

    it "reads the screenshots it kept again, under the name the user gave it" do
      draft = user.drafts.create!(data: { "name" => "奶油烤鸡" }, screenshot_count: 1, status: :failed,
                                  failure_reason: :cleanup_failed,
                                  images: [ DraftImage.new(position: 1, content_type: "image/png", data: "png") ])

      expect { post retry_draft_path(draft) }.to have_enqueued_job(ImportRecipeJob).with(draft, "en")

      expect(response).to redirect_to(drafts_path)
      expect(flash[:alert]).to be_nil
      expect(draft.reload).to have_attributes(status: "reading", failure_reason: nil, title: "奶油烤鸡")
      expect(draft.images.count).to eq 1
    end

    it "is only for the user's own failed drafts" do
      ready = user.drafts.create!(source_url: "https://example.com/ready", status: :ready)
      theirs = create(:user).drafts.create!(source_url: "https://example.com/theirs", status: :failed)

      post retry_draft_path(ready)
      expect(response).to have_http_status(:not_found)
      post retry_draft_path(theirs)
      expect(response).to have_http_status(:not_found)
    end
  end
end
