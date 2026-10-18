class Ingredient < ApplicationRecord
  include NameSearchable

  belongs_to :user
  belongs_to :aisle
  has_many :recipe_ingredients, dependent: :restrict_with_error
  has_many :recipes, through: :recipe_ingredients
  has_many :grocery_list_items, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }, length: { maximum: 100 }
  validate :aisle_must_belong_to_user

  normalizes :name, with: ->(name) { name.strip }

  private

  def aisle_must_belong_to_user
    errors.add(:aisle, :invalid) if aisle && user && aisle.user_id != user_id
  end
end
