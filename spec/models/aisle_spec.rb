require "rails_helper"

RSpec.describe Aisle do
  let(:user) { create(:user) } # with the default aisles, Produce first and Other last

  def keys = user.aisles.ordered.pluck(:key)

  describe "#move_to" do
    it "puts the aisle at that place among the others, and keeps Other last" do
      user.aisles.find_by!(key: "produce").move_to(2)

      expect(keys).to eq %w[meat_seafood dairy_eggs produce bakery pantry spices_seasonings frozen beverages other]
      expect(user.aisles.ordered.pluck(:position)).to eq (1..9).map { _1 * 10 }
    end

    it "puts an aisle moved past the end just before Other" do
      user.aisles.find_by!(key: "produce").move_to(99)

      expect(keys.last(2)).to eq %w[produce other]
    end

    it "leaves Other where it is" do
      user.aisles.find_by!(key: "other").move_to(0)

      expect(keys.first).to eq "produce"
      expect(keys.last).to eq "other"
    end
  end
end
