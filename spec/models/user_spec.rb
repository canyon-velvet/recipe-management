require "rails_helper"

RSpec.describe User do
  it "starts in Central Time, and takes only a time zone Rails knows" do
    user = create(:user)
    expect(user.time_zone).to eq "Central Time (US & Canada)"

    expect(user.update(time_zone: "Beijing")).to be true
    expect(user.update(time_zone: "Mars/Olympus")).to be false
  end
end
