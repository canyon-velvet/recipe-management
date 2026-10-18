require "rails_helper"

RSpec.describe "Suggested preferences in the assistant's replies", type: :request do
  let(:user) { create(:user) }
  let(:turbo_stream) { { "Accept" => "text/vnd.turbo-stream.html" } }
  let(:reply) do
    create(:message, conversation: create(:conversation, user: user), role: "assistant", content: "Noted.",
                     preference_suggestions: [ { "category" => "avoid", "value" => "peanut", "state" => "pending" } ])
  end

  before do
    allow(CleanRecipeService).to receive(:available?).and_return(true)
    log_in_as user
  end

  it "saves the suggestion when the user clicks Save, and shows it saved" do
    post save_assistant_message_suggestion_path(reply, 0), headers: turbo_stream

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(target="#{ActionView::RecordIdentifier.dom_id(reply)}"), "Saved to Preferences")
    expect(user.preferences.sole).to have_attributes(category: "avoid", value: "peanut")
  end

  it "dismisses it on Skip, saving nothing" do
    post dismiss_assistant_message_suggestion_path(reply, 0), headers: turbo_stream

    expect(response.body).to include("Not saved")
    expect(reply.reload.preference_suggestions.sole["state"]).to eq "dismissed"
    expect(user.preferences).to be_empty
  end

  it "only touches the user's own replies, and suggestions they have" do
    someone_elses = create(:message, conversation: create(:conversation), role: "assistant", content: "Hi",
                                     preference_suggestions: reply.preference_suggestions)

    post save_assistant_message_suggestion_path(someone_elses, 0), headers: turbo_stream
    expect(response).to have_http_status(:not_found)

    post save_assistant_message_suggestion_path(reply, 1), headers: turbo_stream
    expect(response).to have_http_status(:not_found)
    expect(Preference.count).to eq 0
  end
end
