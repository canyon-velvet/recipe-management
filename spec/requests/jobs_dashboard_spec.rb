require "rails_helper"

RSpec.describe "The jobs dashboard", type: :request do
  it "shows an admin the jobs, without a password of its own" do
    log_in_as create(:user, :admin)

    get "/jobs"
    follow_redirect! while response.redirect?

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Queues")

    patch locale_path, params: { locale: "zh-CN" } # in English still, as it comes, but it works
    get "/jobs"
    follow_redirect! while response.redirect?
    expect(response).to have_http_status(:ok)
  end

  it "isn't there for anyone else" do
    get "/jobs"
    expect(response).to have_http_status(:not_found)

    log_in_as create(:user)
    get "/jobs"
    expect(response).to have_http_status(:not_found)
  end
end
