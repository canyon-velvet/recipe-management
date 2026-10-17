require "rails_helper"

RSpec.describe "Aisles", type: :request do
  let(:user) { create(:user) }

  before { post login_path, params: { username: user.username, password: "password" } }

  describe "moving an aisle" do
    it "saves its new place, and answers with nothing for the pop-up to redraw" do
      produce = user.aisles.find_by!(key: "produce")

      patch move_aisle_path(produce), params: { position: 1 }

      expect(response).to have_http_status(:no_content)
      expect(user.aisles.ordered.pluck(:key).first(2)).to eq %w[meat_seafood produce]
    end

    it "can't move another user's aisle" do
      theirs = create(:user).aisles.find_by!(key: "produce")

      patch move_aisle_path(theirs), params: { position: 3 }

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.position).to eq 10
    end
  end
end
