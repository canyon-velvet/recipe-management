class Source < ApplicationRecord
  include NameSearchable

  belongs_to :user
  has_many :recipes, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }

  normalizes :name, with: ->(name) { name.strip }

  # The sources the user saves the most recipes from first, for the source picker's chips
  scope :most_used, -> { left_joins(:recipes).group(:id).order(Arel.sql("COUNT(recipes.id) DESC"), :name) }
end
