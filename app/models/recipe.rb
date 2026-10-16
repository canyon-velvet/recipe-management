class Recipe < ApplicationRecord
  belongs_to :source, autosave: true
  belongs_to :user
  has_many :recipe_ingredients, dependent: :destroy, inverse_of: :recipe
  has_many :ingredients, through: :recipe_ingredients
  has_many :steps, -> { order(:position) }, class_name: "RecipeStep", dependent: :destroy, inverse_of: :recipe
  has_many :recipe_tags, dependent: :destroy
  has_many :tags, -> { ordered }, through: :recipe_tags, after_add: :touch_if_persisted, after_remove: :touch_if_persisted
  has_many :meal_slot_recipes, dependent: :destroy
  has_many :meal_slots, through: :meal_slot_recipes

  # Optional whole numbers: how many people it serves and how long it takes. The caps catch typos and keep imported
  # values within the integer columns (a week is the longest time a recipe can take).
  COUNT_LIMITS = { servings: 100, prep_minutes: 10_080, cook_minutes: 10_080, total_minutes: 10_080 }.freeze

  # A draft's source the user doesn't have yet; it's created when the recipe saves.
  attr_accessor :new_source_name

  validates :name, presence: true
  validates :source_url, http_url: true, allow_blank: true
  validates :source_url, uniqueness: { scope: :user_id }, allow_nil: true
  COUNT_LIMITS.each do |attribute, max|
    validates attribute, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: max },
                         allow_nil: true
  end
  validate :must_have_steps
  validate :source_must_belong_to_user

  # One canonical form per page, so the same recipe link can't be saved twice in different spellings.
  normalizes :source_url, with: ->(url) { RecipeLink.normalize(url) }

  accepts_nested_attributes_for :recipe_ingredients, allow_destroy: true, reject_if: :blank_ingredient_row?
  accepts_nested_attributes_for :steps, allow_destroy: true,
                                        reject_if: ->(attributes) { attributes["id"].blank? && attributes["body"].blank? }

  # The form submits each step's position; renumber 1..n in that order so gaps or duplicates never persist.
  before_validation :renumber_steps
  before_validation :use_new_source, if: -> { source.nil? && new_source_name.present? }
  # Sources often give prep and cook time without a total. Filled only when saving, so a form that fails
  # validation comes back with Total still blank and keeps adding up later changes.
  before_save :fill_total_minutes, if: -> { total_minutes.nil? && prep_minutes && cook_minutes }

  scope :search_by_name, ->(query) { where("name ILIKE ?", "%#{query}%") if query.present? }
  scope :tagged, ->(tag_key) {
    where(id: RecipeTag.joins(:tag).where(tags: { key: tag_key }).select(:recipe_id)) if tag_key.present?
  }
  # Recipes with an ingredient whose name contains the text, e.g. "egg" finds "eggs" and "egg yolk".
  scope :with_ingredient, ->(text) { where(id: RecipeIngredient.named_like(text).select(:recipe_id)) }
  # What a card in the assistant's chat reads: the tags for its emoji, the ingredients for avoided items.
  scope :for_cards, -> { includes(:tags, recipe_ingredients: :ingredient) }

  # Shown with a "new" badge in the form until the recipe saves.
  def new_source? = new_source_name.present? && (source.nil? || source.new_record?)

  # The description and the tips at its end, apart: [description, tips], each nil when there's none. Imports put the
  # tips under a bold "Tips" line in the reviewer's language (BuildRecipeFromDraftService); typing one does the same,
  # and the tips under a second one join the first. Line ends sent as \r\n (a plain form post) are evened out first.
  def description_and_tips
    headings = I18n.available_locales.map { |locale| Regexp.escape(I18n.t("recipes.tips_heading", locale: locale)) }
    text, *tips = description.to_s.gsub("\r\n", "\n").split(/^\*\*(?:#{headings.join("|")})\*\*[ \t]*$/)
    [ text.to_s.strip.presence, tips.map(&:strip).compact_blank.join("\n\n").presence ]
  end

  # The emoji on the recipe's card: one of its tags', picked by the recipe's id, so cards vary but a recipe always
  # shows the same one. Nil without tags. Uses the loaded tags, so a list that includes them adds no queries.
  def card_icon
    with_icons = tags.select(&:icon)
    with_icons[id.to_i % with_icons.size].icon if with_icons.any?
  end

  # The items of a user's avoid list (see User#avoided_ingredients) that this recipe's ingredients contain, ignoring
  # case: "peanut" matches "Peanut butter". Uses the loaded ingredients, so a list that includes
  # recipe_ingredients: :ingredient adds no queries.
  def avoided_items(avoid_list)
    names = recipe_ingredients.map { |row| row.ingredient.name.downcase }
    avoid_list.select { |item| names.any? { |name| name.include?(item.downcase) } }
  end

  private

  # A row with nothing filled in is dropped. A draft's New row always carries an aisle choice, which doesn't count.
  def blank_ingredient_row?(attributes) = attributes.except("new_aisle_id", "_destroy").values.all?(&:blank?)

  def use_new_source
    self.source = user.sources.named(new_source_name).first || user.sources.build(name: new_source_name)
  end

  def fill_total_minutes
    total = prep_minutes + cook_minutes
    self.total_minutes = total if total <= COUNT_LIMITS[:total_minutes]
  end

  def kept_steps
    steps.reject(&:marked_for_destruction?)
  end

  def must_have_steps
    errors.add(:steps, :blank) if kept_steps.empty?
  end

  def source_must_belong_to_user
    errors.add(:source, :invalid) if source && user && source.user_id != user_id
  end

  def renumber_steps
    kept_steps.each_with_index
              .sort_by { |step, index| [ step.position || Float::INFINITY, index ] }
              .each.with_index(1) { |(step, _), position| step.position = position }
  end

  # Tag changes only write recipe_tags rows, so bump updated_at to keep recently edited recipes on top.
  def touch_if_persisted(_tag)
    touch if persisted?
  end
end
