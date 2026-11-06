require "rails_helper"
require Rails.root.join("db/migrate/20261106120000_add_icon_to_recipes")

# Each recipe gets the icon it showed before it had one of its own: of its tags with an emoji, in their order, the one
# its id picks. (Checked against Recipe#card_icon, then removed, on 600 random recipes: all the same.)
RSpec.describe AddIconToRecipes do
  def backfill
    Recipe.update_all(icon: nil)
    described_class.new.tap { _1.verbose = false }.backfill_icons
  end

  let(:user) { create(:user) }
  let(:dinner) { create(:tag, key: "dinner", kind: "meal", position: 30) }
  let(:spicy) { create(:tag, key: "spicy", kind: "flavor", position: 180) }

  it "picks one of the recipe's tags' emoji, in the tags' order, by the recipe's id" do
    recipes = create_list(:recipe, 2, user: user, tags: [ spicy, dinner ])

    backfill

    recipes.each { |recipe| expect(recipe.reload.icon).to eq [ "🍛", "🌶️" ][recipe.id % 2] }
  end

  it "takes a user's own tag's emoji, skips their tags without one, and orders theirs by when they were made" do
    noodles = user.tags.create!(name: "Noodles", emoji: "🍜")
    plain = user.tags.create!(name: "Plain")
    korean = user.tags.create!(name: "Korean", emoji: "🇰🇷")
    recipes = create_list(:recipe, 2, user: user, tags: [ korean, plain, noodles ])

    backfill

    recipes.each { |recipe| expect(recipe.reload.icon).to eq [ "🍜", "🇰🇷" ][recipe.id % 2] }
  end

  it "leaves a recipe with no tag emoji on the placeholder" do
    untagged = create(:recipe, user: user)
    plain_only = create(:recipe, user: user, tags: [ user.tags.create!(name: "Plain") ])

    backfill

    expect([ untagged.reload.icon, plain_only.reload.icon ]).to eq [ nil, nil ]
  end
end
