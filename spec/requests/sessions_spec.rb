require "rails_helper"

RSpec.describe "Logging out", type: :request do
  it "ends the whole session but keeps the chosen language" do
    user = create(:user)
    patch locale_path, params: { locale: "zh-CN" }
    post login_path, params: { username: user.username, password: "password" }
    session_id = session.id

    delete logout_path

    expect(session[:user_id]).to be_nil
    expect(session[:locale]).to eq "zh-CN"
    expect(session.id).not_to eq session_id
  end

  it "keeps the user logged in for 30 days from their last visit, also in an app added to the iPhone's Home Screen" do
    user = create(:user)

    freeze_time do
      post login_path, params: { username: user.username, password: "password" }

      # Without an expiry the cookie lasts until the browser closes, and iOS drops it whenever a Home Screen app quits
      session_cookie = response.headers["Set-Cookie"].lines.find { |line| line.start_with?("_recipe_management_session=") }
      expect(session_cookie).to include("expires=#{(Time.now.utc + 30.days.to_i).httpdate}")
    end
  end
end
