require "rails_helper"

RSpec.describe "Markdown previews", type: :request do
  let(:user) { create(:user) }

  it "renders the text as it will be shown, without its HTML" do
    post login_path, params: { username: user.username, password: "password" }

    post markdown_preview_path, params: { text: %(**Bold** <img src="x" onerror="alert(1)">) }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<strong>Bold</strong>")
    expect(response.body).not_to include("<img", "onerror")
  end

  it "previews at most as much text as a recipe can hold" do
    post login_path, params: { username: user.username, password: "password" }

    post markdown_preview_path, params: { text: "a" * 20_000 + "TAIL" }

    expect(response.body).to include("a" * 20_000)
    expect(response.body).not_to include("TAIL")
  end

  it "needs a logged-in user" do
    post markdown_preview_path, params: { text: "**Bold**" }

    expect(response).to redirect_to(login_path)
  end
end
