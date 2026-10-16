require "rails_helper"

RSpec.describe "Web app manifest", type: :request do
  it "is linked from every page, the login page included" do
    get login_path

    expect(response.body).to include(%(<link rel="manifest" href="/manifest" crossorigin="use-credentials">))
    expect(response.body).to include(%(<link rel="apple-touch-icon" href="/apple-touch-icon.png">))
  end

  it "names the app and points at icons that exist, without logging in" do
    get pwa_manifest_path

    manifest = response.parsed_body
    expect(manifest).to include("name" => "Recipe Manager", "short_name" => "Recipes", "start_url" => "/",
                                "display" => "standalone")
    manifest["icons"].each do |icon|
      expect(Rails.public_path.join(icon["src"].delete_prefix("/"))).to exist
    end
  end

  it "names the app in the visitor's language: the browser's, or the one chosen in the app" do
    get pwa_manifest_path, headers: { "Accept-Language" => "zh-CN" }
    expect(response.parsed_body).to include("name" => "食谱管理", "short_name" => "食谱管理")

    patch locale_path, params: { locale: "zh-CN" }
    get pwa_manifest_path, headers: { "Accept-Language" => "en" }
    expect(response.parsed_body).to include("name" => "食谱管理")
  end

  it "is only JSON" do
    get "/manifest.html"

    expect(response).to have_http_status(:not_found)
  end
end
