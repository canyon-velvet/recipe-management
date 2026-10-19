require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  it "connects the logged-in user" do
    user = create(:user)

    connect "/cable", session: { user_id: user.id }

    expect(connection.current_user).to eq user
  end

  it "refuses a visitor who isn't logged in" do
    expect { connect "/cable" }.to have_rejected_connection
    expect { connect "/cable", session: { user_id: 0 } }.to have_rejected_connection
  end
end
