class Tag < ApplicationRecord
  include TranslatedName

  KINDS = %w[meal cuisine diet flavor convenience].freeze

  # Shown on recipe cards. Plain emoji, drawn by the viewer's system font: nothing to download or credit.
  ICONS = {
    "breakfast" => "🥞", "lunch" => "🍱", "dinner" => "🍛", "snack" => "🍪", "dessert" => "🍰",
    "appetizer" => "🍢", "soup" => "🍲", "salad" => "🥗", "drink" => "🧋",
    "chinese" => "🥟", "italian" => "🍝", "japanese" => "🍣", "mexican" => "🌮", "american" => "🍔",
    "vegetarian" => "🥦", "vegan" => "🥑", "gluten_free" => "🍚",
    "spicy" => "🌶️",
    "quick" => "🍳", "kid_friendly" => "🧁", "make_ahead" => "🥫"
  }.freeze

  has_many :recipe_tags, dependent: :destroy
  has_many :recipes, through: :recipe_tags

  enum :kind, KINDS.index_by(&:itself), validate: true

  validates :key, uniqueness: true
  validates :position, presence: true

  scope :ordered, -> { order(:position) }

  def self.kind_name(kind) = I18n.t(kind, scope: :tag_kinds)

  def icon = ICONS[key]

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
end
