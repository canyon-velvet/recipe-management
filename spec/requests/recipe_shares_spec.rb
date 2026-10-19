require "rails_helper"

RSpec.describe "Sharing a recipe", type: :request do
  let(:user) { create(:user) }
  let(:recipe) do
    create(:recipe, user: user, name: "Mapo tofu", description: "Silky tofu in a **numbing** sauce.\n\n**Tips**\n\n- Cut gently.")
  end

  before { log_in_as user }

  it "makes a link once, and keeps it when shared again" do
    post recipe_share_path(recipe)
    expect(response).to redirect_to(recipe_share_path(recipe))
    token = recipe.reload.share_token
    expect(token.length).to be >= 24

    post recipe_share_path(recipe)
    expect(recipe.reload.share_token).to eq token

    get recipe_share_path(recipe)
    expect(response.body).to include(shared_recipe_url(token))
  end

  it "stops the link working, and a new share makes a new one" do
    post recipe_share_path(recipe)
    old_token = recipe.reload.share_token

    delete recipe_share_path(recipe)
    expect(response).to redirect_to(recipe_path(recipe))
    expect(recipe.reload.share_token).to be_nil
    get shared_recipe_path(old_token)
    expect(response).to have_http_status(:not_found)

    post recipe_share_path(recipe)
    expect(recipe.reload.share_token).to be_present
    expect(recipe.share_token).not_to eq old_token
  end

  it "sends an unshared recipe's share page back to the recipe" do
    get recipe_share_path(recipe)
    expect(response).to redirect_to(recipe_path(recipe))
  end

  it "doesn't share another user's recipe" do
    other = create(:recipe)

    post recipe_share_path(other)
    expect(response).to have_http_status(:not_found)
    expect(other.reload.share_token).to be_nil
  end

  describe "the shared page" do
    before do
      post recipe_share_path(recipe)
      delete logout_path
    end

    it "shows the recipe to anyone with the link, read-only, unindexed, with a link preview" do
      get shared_recipe_path(recipe.reload.share_token), headers: { "User-Agent" => "facebookexternalhit/1.1" }

      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("h1").text).to eq "Mapo tofu"
      expect(page.at_css(".recipe-tips").text).to include "Cut gently."
      expect(page.css(".recipe-heading-actions")).to be_empty
      expect(response.body).not_to include(user.username)
      expect(page.at_css("meta[name=robots]")["content"]).to eq "noindex, nofollow"
      expect(page.at_css("meta[property='og:title']")["content"]).to eq "Mapo tofu"
      expect(page.at_css("meta[property='og:description']")["content"]).to eq "Silky tofu in a numbing sauce."
    end

    it "opens in an older browser too, which the app's own pages turn away" do
      ios16 = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
              "Version/16.6 Mobile/15E148 Safari/604.1"

      get shared_recipe_path(recipe.reload.share_token), headers: { "User-Agent" => ios16 }
      expect(response).to have_http_status(:ok)

      get login_path, headers: { "User-Agent" => ios16 }
      expect(response).to have_http_status(:not_acceptable)
    end

    it "is in the visitor's language" do
      get shared_recipe_path(recipe.reload.share_token), headers: { "Accept-Language" => "zh-CN,zh;q=0.9" }

      expect(Nokogiri::HTML(response.body).at_css("html")["lang"]).to eq "zh-CN"
    end

    it "is not found for an unknown link" do
      get shared_recipe_path("not-a-real-token")
      expect(response).to have_http_status(:not_found)
    end
  end
end
