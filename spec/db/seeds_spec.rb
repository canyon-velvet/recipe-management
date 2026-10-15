require "rails_helper"

# The seeds run on every deploy (render.yaml's preDeployCommand), so running them again must change nothing a user did.
RSpec.describe "db/seeds.rb" do
  def seed = expect { load Rails.root.join("db/seeds.rb") }.to output.to_stdout

  it "seeds the tags, and leaves a default aisle a user deleted deleted" do
    user = create(:user)
    user.aisles.find_by!(key: "frozen").destroy!

    seed

    expect(Tag.count).to be > 0
    expect(user.aisles.where(key: "frozen")).to be_empty
  end

  it "gives the default aisles to a user who has none" do
    user = create(:user)
    user.aisles.delete_all

    seed

    expect(user.aisles.count).to eq Aisle::DEFAULT_KEYS.size
  end
end
