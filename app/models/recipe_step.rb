class RecipeStep < ApplicationRecord
  belongs_to :recipe

  validates :body, presence: true, length: { maximum: 5_000 }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
