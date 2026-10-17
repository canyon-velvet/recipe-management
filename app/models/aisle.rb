class Aisle < ApplicationRecord
  include TranslatedName

  DEFAULT_KEYS = %w[produce meat_seafood dairy_eggs bakery pantry spices_seasonings frozen beverages other].freeze

  belongs_to :user
  has_many :ingredients, dependent: :restrict_with_error

  validates :key, uniqueness: { scope: :user_id }, allow_nil: true
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }, if: :custom_name?
  validate :name_must_differ_from_default_aisles, if: :custom_name?
  validates :position, presence: true

  # Blank becomes NULL, so a default aisle whose name is cleared goes back to its translated name.
  normalizes :name, with: ->(name) { name.strip.presence }

  # Saving a default aisle under its own translated name would freeze it in one language; keep it translated instead.
  before_validation :clear_name_matching_default, if: :key?

  scope :ordered, -> { order(:position, :id) }

  # Idempotent: gives the user any default aisle they don't have yet, in shopping order.
  def self.create_defaults_for(user)
    DEFAULT_KEYS.each.with_index(1) do |key, i|
      user.aisles.find_or_create_by!(key: key) { |aisle| aisle.position = i * 10 }
    end
  end

  # A new aisle goes just before Other, which stays the catch-all at the end of the list.
  # Locking the user makes concurrent adds take turns, so two aisles never share a position.
  def self.add_before_other(user, name)
    transaction do
      user.lock!
      position = user.aisles.find_by(key: "other")&.position || (user.aisles.maximum(:position).to_i + 10)
      aisle = user.aisles.new(name: name, position: position)
      user.aisles.where(position: position..).update_all("position = position + 10") if aisle.valid?
      aisle.save
      aisle
    end
  end

  def self.default_labels(key) = I18n.available_locales.map { |locale| I18n.t(key, scope: :aisles, locale: locale) }

  def other? = key == "other"

  # The name as stored, ignoring an unsaved rename.
  def saved_name = attribute_in_database(:name) || (key && I18n.t(key, scope: :aisles))

  # Puts the aisle at index (from 0) among the aisles before Other, which stays last, and numbers them all again in
  # tens. Locking the user makes concurrent moves take turns.
  def move_to(index)
    return if other?

    transaction do
      user.lock!
      aisles = movable_siblings.to_a
      aisles.insert(index.clamp(0, aisles.size), self)
      aisles << user.aisles.find_by(key: "other")
      aisles.compact.each.with_index(1) { |aisle, i| aisle.update_column(:position, i * 10) }
    end
  end

  # Other is the catch-all, so it can't be deleted; anything in this aisle moves there.
  def destroy_moving_ingredients_to_other
    if other?
      errors.add(:base, :other_aisle_permanent)
      return false
    end

    transaction do
      ingredients.update_all(aisle_id: user.aisles.find_by!(key: "other").id, updated_at: Time.current)
      destroy!
    end
  end

  private

  # Other stays last, so it never moves among the rest.
  def movable_siblings = user.aisles.ordered.where.not(id: id).where("key IS NULL OR key <> 'other'")

  def clear_name_matching_default
    self.name = nil if self[:name] && self.class.default_labels(key).any? { |label| label.casecmp?(self[:name]) }
  end

  # Default aisles keep their name in the locale files, so the uniqueness index can't see it.
  def name_must_differ_from_default_aisles
    labels = user.aisles.where.not(key: nil).pluck(:key).flat_map { |key| self.class.default_labels(key) }
    errors.add(:name, :taken) if labels.any? { |label| label.casecmp?(self[:name]) }
  end
end
