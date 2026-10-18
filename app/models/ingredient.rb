class Ingredient < ApplicationRecord
  include NameSearchable

  belongs_to :user
  belongs_to :aisle
  has_many :recipe_ingredients, dependent: :restrict_with_error
  has_many :recipes, through: :recipe_ingredients
  has_many :grocery_list_items, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }, length: { maximum: 100 }
  validates :aisle, same_user: true

  normalizes :name, with: ->(name) { name.strip }
end
