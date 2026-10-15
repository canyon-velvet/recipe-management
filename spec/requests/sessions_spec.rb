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
end
