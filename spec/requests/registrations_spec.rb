require "rails_helper"

RSpec.describe "Signing up", type: :request do
  let(:invite) { create(:invite) }
  let(:account) { { username: "newcook", password: "secret123", password_confirmation: "secret123" } }

  it "shows the form for an invite link, and creates the account with it" do
    get register_path(invite_token: invite.token)
    expect(response).to have_http_status(:ok)

    post register_path, params: { invite_token: invite.token, user: account }

    user = User.find_by!(username: "newcook")
    expect(response).to redirect_to(root_path)
    expect(invite.reload).to have_attributes(used_by: user)
  end

  {
    "without an invite" => -> { nil },
    "with an unknown invite" => -> { "not-a-real-token" },
    "with a used invite" => -> { create(:invite, used_at: 1.day.ago).token },
    "with an expired invite" => -> { create(:invite, expires_at: 1.minute.ago).token }
  }.each do |case_name, token|
    it "is refused #{case_name}" do
      invite_token = instance_exec(&token)

      get register_path(invite_token: invite_token)
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Sign-up is by invitation")

      expect { post register_path, params: { invite_token: invite_token, user: account } }
        .not_to change(User, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "shows the account's errors and keeps the invite unused" do
    post register_path, params: { invite_token: invite.token, user: account.merge(password_confirmation: "nope") }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(%(value="#{invite.token}"))
    expect(invite.reload.used_at).to be_nil
  end

  it "sends someone already logged in home, without using up the invite" do
    post login_path, params: { username: create(:user).username, password: "password" }

    get register_path(invite_token: invite.token)
    expect(response).to redirect_to(root_path)

    expect { post register_path, params: { invite_token: invite.token, user: account } }.not_to change(User, :count)
    expect(invite.reload.used_at).to be_nil
  end

  it "has no sign-up link on the login page" do
    get login_path

    expect(response.body).not_to include(register_path)
  end
end
