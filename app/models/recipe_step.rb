class RecipeStep < ApplicationRecord
  belongs_to :recipe

  validates :body, presence: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
