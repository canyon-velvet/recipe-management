require "rails_helper"

RSpec.describe ImportRecipeJob do
  include ActiveJob::TestHelper

  let(:draft) { create(:user).drafts.create!(source_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") }

  it "waits out Claude's and Gemini's rate limits, then fails the draft with whose it was" do
    { CleanRecipeService::TemporaryError => "cleanup_failed", WatchVideoService::TemporaryError => "video_failed" }
      .each do |error, reason|
        draft.update!(status: :reading, failure_reason: nil)
        service = instance_double(ImportRecipeService)
        allow(service).to receive(:call).and_raise(error)
        allow(ImportRecipeService).to receive(:new).and_return(service)

        perform_enqueued_jobs { described_class.perform_later(draft, "en") }

        expect(service).to have_received(:call).exactly(5).times
        expect(draft.reload).to have_attributes(status: "failed", failure_reason: reason)
      end
  end
end
