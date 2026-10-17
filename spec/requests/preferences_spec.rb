require "rails_helper"

RSpec.describe "Preferences", type: :request do
  let(:user) { create(:user) }

  before { post login_path, params: { username: user.username, password: "password" } }

  it "lists the user's preferences under every category" do
    create(:preference, user: user, category: "avoid", value: "peanuts")
    create(:preference, user: create(:user), category: "avoid", value: "shellfish")

    get preferences_path

    titles = Nokogiri::HTML(response.body).css("[id^='preferences_'] .preference-title").map(&:text)
    expect(titles).to eq [ "Household", "Diet", "Likes", "Dislikes", "Avoid" ] # who you cook for comes first
    expect(response.body).to include("peanuts")
    expect(response.body).not_to include("shellfish")
  end

  it "adds a preference and returns just that category's card" do
    post preferences_path, params: { preference: { category: "likes", value: "spicy food" } }

    expect(user.preferences.likes.pluck(:value)).to eq [ "spicy food" ]
    expect(response.body).to include('id="preferences_likes"', "spicy food")
  end

  it "shows the error in the card when the preference is invalid" do
    create(:preference, user: user, category: "likes", value: "spicy food")

    post preferences_path, params: { preference: { category: "likes", value: "Spicy food" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Preference is already listed")
  end

  it "shows the household message when one is already set (e.g. from a stale tab)" do
    create(:preference, user: user, category: "household", value: "4 people")

    post preferences_path, params: { preference: { category: "household", value: "2 adults" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Household already has a value")
  end

  it "shows the usual error, not a crash, when another tab saved the same fact first" do
    # The other tab wins the race after this request's validation passed; the real insert then hits the unique index.
    allow_any_instance_of(Preference).to receive(:save).and_wrap_original do |save, *|
      create(:preference, user: user, category: "avoid", value: "peanuts")
      save.call(validate: false)
    end

    post preferences_path, params: { preference: { category: "avoid", value: "Peanuts" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Preference is already listed")
  end

  it "gives each card's fields their own ids" do
    get preferences_path

    ids = Nokogiri::HTML(response.body).css("[id]").map { _1["id"] }
    expect(ids).to eq ids.uniq
    expect(ids).to include("diet_preference_value", "avoid_preference_value")
  end

  it "rejects an unknown category" do
    post preferences_path, params: { preference: { category: "mood", value: "happy" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.preferences).to be_empty
  end

  it "removes the user's own preference" do
    preference = create(:preference, user: user, category: "dislikes", value: "cilantro")

    delete preference_path(preference)

    expect(user.preferences).to be_empty
    expect(response.body).to include('id="preferences_dislikes"')
  end

  it "can't remove another user's preference" do
    other = create(:preference, user: create(:user), category: "avoid", value: "peanuts")

    delete preference_path(other)

    expect(response).to have_http_status(:not_found)
    expect(other.reload).to be_persisted
  end

  it "saves the user's time zone, and keeps a made-up one out" do
    patch time_zone_path, params: { user: { time_zone: "Beijing" } }

    expect(user.reload.time_zone).to eq "Beijing"
    expect(response.body).to include('id="time_zone"', "Saved")

    patch time_zone_path, params: { user: { time_zone: "Mars/Olympus" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(user.reload.time_zone).to eq "Beijing"
  end
end
