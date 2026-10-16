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

  # { tag_id => how many of the user's recipes have it }, for the tags they use; the catalog shows the counts and dims
  # the rest.
  def self.recipe_counts_for(user) = RecipeTag.where(recipe_id: user.recipes.select(:id)).group(:tag_id).count
end
