require "rails_helper"

RSpec.describe Tag do
  describe "the seeded tags" do
    before { expect { load Rails.root.join("db/seeds.rb") }.to output.to_stdout }

    it "puts Spicy in its own Flavor group, after Diet and before Convenience" do
      expect(Tag.find_by!(key: "spicy").kind).to eq "flavor"
      expect(Tag.by_kind.keys).to eq %w[meal cuisine diet flavor convenience]
    end

    it "gives every tag an emoji and a name in both languages" do
      Tag.find_each do |tag|
        expect(tag.icon).to be_present, "#{tag.key} has no emoji"
        I18n.available_locales.each do |locale|
          expect(I18n.t(tag.key, scope: :tags, locale: locale, raise: true)).to be_present
        end
      end
    end

    it "names every group in both languages" do
      Tag::KINDS.each do |kind|
        I18n.available_locales.each do |locale|
          expect(I18n.t(kind, scope: :tag_kinds, locale: locale, raise: true)).to be_present
        end
      end
    end

    it "can be run again without duplicating anything" do
      expect { expect { load Rails.root.join("db/seeds.rb") }.to output.to_stdout }.not_to change(Tag, :count)
    end
  end

  describe ".recipe_counts_for" do
    it "counts the user's own recipes with each tag, and leaves out tags they don't use" do
      user = create(:user)
      chinese = create(:tag, key: "chinese", kind: "cuisine")
      soup = create(:tag, key: "soup", kind: "meal")
      create(:tag, key: "italian", kind: "cuisine")
      create_list(:recipe, 2, user: user, tags: [ chinese ])
      create(:recipe, user: user, tags: [ chinese, soup ])
      create(:recipe, tags: [ soup ]) # someone else's

      expect(Tag.recipe_counts_for(user)).to eq(chinese.id => 3, soup.id => 1)
    end
  end
end
