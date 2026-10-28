# A recipe tag: a built-in one everyone shares (no user; named in the locale files by its key), or one a user made
# for themselves, which keeps the name as typed and can have an emoji. Each user sees the built-in tags and their own.
class Tag < ApplicationRecord
  include TranslatedName

  KINDS = %w[meal cuisine diet flavor convenience other].freeze
  NAME_MAX_LENGTH = 30
  # The longest emoji people pick (a family, a flag of a country's region) are about this many code points
  EMOJI_MAX_LENGTH = 10
  # Users' tags come after the built-in ones, in the order they were made
  CUSTOM_POSITION = 10_000
  # Drawn as an emoji, not text-style like ©: a flag is two regional indicators, a keycap a digit, # or * with ⃣
  EMOJI_START = /\A(
    \p{Regional_Indicator}{2} | (?!\p{Regional_Indicator})\p{Emoji_Presentation} | \p{Extended_Pictographic}\u{FE0F} |
    [\#*0-9]\u{FE0F}?\u{20E3}
  )/x

  # The New tag pop-up's emoji to tap; any other can be typed
  EMOJI_CHOICES = %w[
    🍜 🍲 🍛 🍝 🍣 🍱 🥟 🍙 🍚 🥘 🌮 🍔 🍕 🥗 🥪 🍳 🥞 🥐 🧀 🥩 🍗 🍤 🐟 🥦 🌶️ 🍄 🍅 🍋 🍰 🍪 ☕ 🧋 🍷 🎉 ❤️ ⭐
  ].freeze

  # Shown on recipe cards. Plain emoji, drawn by the viewer's system font: nothing to download or credit.
  ICONS = {
    "breakfast" => "🥞", "lunch" => "🍱", "dinner" => "🍛", "snack" => "🍪", "dessert" => "🍰",
    "appetizer" => "🍢", "soup" => "🍲", "salad" => "🥗", "drink" => "🧋",
    "chinese" => "🥟", "italian" => "🍝", "japanese" => "🍣", "mexican" => "🌮", "american" => "🍔",
    "vegetarian" => "🥦", "vegan" => "🥑", "gluten_free" => "🍚",
    "spicy" => "🌶️",
    "quick" => "🍳", "kid_friendly" => "🧁", "make_ahead" => "🥫"
  }.freeze

  belongs_to :user, optional: true
  has_many :recipe_tags, dependent: :destroy
  has_many :recipes, through: :recipe_tags

  # A user's tag goes under Other unless they choose another group
  enum :kind, KINDS.index_by(&:itself), validate: true, default: "other"

  # squish: also the wide and non-breaking spaces keyboards add. Not for the emoji, joined by invisible characters.
  normalizes :name, with: ->(name) { name.squish.presence }
  normalizes :emoji, with: ->(emoji) { emoji.strip.presence }

  validates :key, uniqueness: true
  validates :position, presence: true
  with_options if: :user_id? do
    validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH },
                     uniqueness: { scope: :user_id, case_sensitive: false }
    validate :name_must_differ_from_built_in_tags
  end
  validate :emoji_must_be_one_emoji, if: :emoji?

  # Filters, drafts and the assistant refer to tags by key, so a user's tag gets one too; after the built-in tags.
  before_validation :assign_key_and_position, on: :create, if: :user_id?

  scope :visible_to, ->(user) { where(user_id: [ nil, user.id ]) }
  scope :ordered, -> { order(:position, :id) }

  def self.kind_name(kind) = I18n.t(kind, scope: :tag_kinds)

  def icon = emoji || ICONS[key]

  # A user's tag is only ever named as typed: its key is made up, with nothing in the locale files
  def name = user_id? ? self[:name] : super

  # { "meal" => [tags…], "cuisine" => […], … } in display order, for the recipe catalog.
  def self.by_kind = ordered.group_by(&:kind)

  # { tag_id => how many of the recipes (the user's, as searched) have it and the tags picked in the other kinds }: how
  # many recipes picking it would add to the list (Recipe.tagged_any_in_each_kind). The catalog shows the counts and
  # dims the tags at none. One query per different set of other kinds' picks: one with nothing picked.
  def self.recipe_counts_for(recipes, picked = [])
    KINDS.group_by { |kind| picked.reject { _1.kind == kind } }.each_with_object({}) do |(others, kinds), counts|
      matching = recipes.tagged_any_in_each_kind(others)
      counts.merge!(RecipeTag.joins(:tag).where(tags: { kind: kinds }, recipe_id: matching.select(:id))
                             .group(:tag_id).count)
    end
  end

  private

  def assign_key_and_position
    self.key ||= "u#{user_id}-#{SecureRandom.alphanumeric(8).downcase}"
    self.position ||= CUSTOM_POSITION
  end

  # The built-in tags keep their names in the locale files, so the uniqueness index can't see them.
  def name_must_differ_from_built_in_tags
    taken = Tag.where(user_id: nil).pluck(:key).flat_map do |key|
      I18n.available_locales.map { |locale| I18n.t(key, scope: :tags, locale: locale) }
    end
    errors.add(:name, :taken) if taken.any? { |label| label.casecmp?(self[:name]) }
  end

  # One emoji as people pick it: a single character on screen, such as 🍜, 🌶️ (with its variation selector) or 🇰🇷,
  # and short, so it isn't one with marks piled on it or dozens joined into one
  def emoji_must_be_one_emoji
    one = emoji.length <= EMOJI_MAX_LENGTH && emoji.grapheme_clusters.one? && emoji.match?(EMOJI_START)
    errors.add(:emoji, :invalid) unless one
  end
end
