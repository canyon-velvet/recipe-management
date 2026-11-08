require "rails_helper"

RSpec.describe "The Light / Dark / Auto switch", type: :request do
  let(:user) { create(:user) }
  let(:turbo_stream) { { "Accept" => "text/vnd.turbo-stream.html" } }

  def html = Nokogiri::HTML(response.body)
  def theme_colors = html.css("meta[name=theme-color]").to_h { [ _1["data-scheme"], _1["media"] ] }

  it "starts on Auto, following the device: the page and the phone's status bar" do
    log_in_as user
    get root_path

    expect(html.at_css("html")["data-theme"]).to eq "auto"
    expect(theme_colors).to eq("light" => "(prefers-color-scheme: light)", "dark" => "(prefers-color-scheme: dark)")
    expect(html.at_css("#appearance [aria-checked=true]")["value"]).to eq "auto"
  end

  it "keeps the choice for the account, and opens every page in it" do
    log_in_as user

    patch appearance_path, params: { appearance: "dark" }, headers: turbo_stream
    expect(response.media_type).to eq "text/vnd.turbo-stream.html"
    expect(user.reload.appearance).to eq "dark"
    expect(html.at_css("template [aria-checked=true]")["value"]).to eq "dark" # the switch, redrawn to match

    get recipes_path
    expect(html.at_css("html")["data-theme"]).to eq "dark"
    expect(theme_colors).to eq("light" => "not all", "dark" => "all")
  end

  it "goes back to the page without JavaScript, and refuses a choice that isn't one" do
    log_in_as user

    patch appearance_path, params: { appearance: "light" }, headers: { "Referer" => recipes_url }
    expect(response).to redirect_to(recipes_url)
    expect(user.reload.appearance).to eq "light"

    patch appearance_path, params: { appearance: "sepia" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.appearance).to eq "light"
  end

  it "follows the device for anyone not logged in, and needs logging in to choose" do
    get login_path
    expect(html.at_css("html")["data-theme"]).to eq "auto"

    patch appearance_path, params: { appearance: "dark" }
    expect(response).to redirect_to(login_path)
  end
end
