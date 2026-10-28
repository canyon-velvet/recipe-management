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

      expect(Tag.recipe_counts_for(user.recipes)).to eq(chinese.id => 3, soup.id => 1)
    end

    it "counts each tag among the recipes with the tags picked in the other kinds: what picking it would show" do
      user = create(:user)
      chinese = create(:tag, key: "chinese", kind: "cuisine")
      italian = create(:tag, key: "italian", kind: "cuisine")
      soup = create(:tag, key: "soup", kind: "meal")
      dinner = create(:tag, key: "dinner", kind: "meal")
      create(:recipe, user: user, tags: [ chinese, soup ])
      create(:recipe, user: user, tags: [ chinese, dinner ])
      create(:recipe, user: user, tags: [ italian, soup ])

      # Soup picked: the cuisines count among soups; the meals, picked or not, among everything (no cuisine picked)
      expect(Tag.recipe_counts_for(user.recipes, [ soup ]))
        .to eq(chinese.id => 1, italian.id => 1, soup.id => 2, dinner.id => 1)
      # Soup and Chinese: each kind counts among the other's picks
      expect(Tag.recipe_counts_for(user.recipes, [ soup, chinese ]))
        .to eq(chinese.id => 1, italian.id => 1, soup.id => 1, dinner.id => 1)
    end
  end

  describe "a user's own tag" do
    let(:user) { create(:user) }

    it "goes under Other unless another group is chosen, named as typed in every language" do
      tag = user.tags.create!(name: " Korean ")

      expect(tag).to have_attributes(kind: "other", name: "Korean", user: user)
      expect(tag.key).to be_present # what filters and imports refer to it by, as for the built-in tags
      expect(I18n.with_locale(:"zh-CN") { tag.name }).to eq "Korean"
      expect(user.tags.create!(name: "Gochujang", kind: "flavor").kind).to eq "flavor"
    end

    it "needs a name of at most 30 characters, not one of the user's other tags or a built-in one, ignoring case" do
      expect { load Rails.root.join("db/seeds.rb") }.to output.to_stdout
      user.tags.create!(name: "Korean")

      expect(user.tags.build(name: " ")).not_to be_valid
      expect(user.tags.build(name: "a" * 31)).not_to be_valid
      expect(user.tags.build(name: "korean")).not_to be_valid
      expect(user.tags.build(name: "Dinner")).not_to be_valid
      expect(user.tags.build(name: "晚餐")).not_to be_valid # Dinner, in Chinese
      expect(create(:user).tags.build(name: "Korean")).to be_valid # another user's is theirs
    end

    it "takes one emoji, or none, and shows it on cards" do
      expect(user.tags.create!(name: "Noodles", emoji: "🍜").icon).to eq "🍜"
      expect(user.tags.create!(name: "Hot", emoji: "🌶️").icon).to eq "🌶️" # with its variation selector
      expect(user.tags.create!(name: "Korean", emoji: "🇰🇷").icon).to eq "🇰🇷" # a flag: two code points
      expect(user.tags.create!(name: "Plain", emoji: " ").icon).to be_nil

      %w[🍜🍜 a ab :)].each { |emoji| expect(user.tags.build(name: "Other #{emoji}", emoji: emoji)).not_to be_valid }
    end

    it "is seen only by its user, besides the built-in tags, and listed after them" do
      dinner = create(:tag, key: "dinner", kind: "meal")
      korean = user.tags.create!(name: "Korean", kind: "cuisine")
      someone_elses = create(:user).tags.create!(name: "Thai")
      chinese = create(:tag, key: "chinese", kind: "cuisine")

      expect(Tag.visible_to(user).ordered).to eq [ dinner, chinese, korean ]
      expect(Tag.visible_to(user)).not_to include(someone_elses)
    end

    it "is deleted with its user" do
      user.tags.create!(name: "Korean")

      expect { user.destroy }.to change(Tag, :count).by(-1)
    end
  end
end
