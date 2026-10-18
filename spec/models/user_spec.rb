require "rails_helper"

RSpec.describe User do
  it "starts in Central Time, and takes only a time zone Rails knows" do
    user = create(:user)
    expect(user.time_zone).to eq "Central Time (US & Canada)"

    expect(user.update(time_zone: "Beijing")).to be true
    expect(user.update(time_zone: "Mars/Olympus")).to be false
  end

  it "counts the assistant's daily limit over the last 24 hours, whatever the time zone says the day is" do
    user = create(:user)
    conversation = user.current_conversation!
    travel_to Time.utc(2026, 10, 19, 11) do
      Message::DAILY_LIMIT.times { conversation.messages.create!(role: :user, content: "Hi") }
    end

    # Noon UTC: already tomorrow in Fiji, still today in Chicago. Neither resets the count.
    travel_to Time.utc(2026, 10, 19, 12) do
      expect(user.assistant_limit_reached?).to be true
      user.update!(time_zone: "Fiji")
      expect(Time.use_zone(user.time_zone) { user.assistant_limit_reached? }).to be true
    end

    travel_to(Time.utc(2026, 10, 20, 11, 1)) { expect(user.assistant_limit_reached?).to be false }
  end
end
