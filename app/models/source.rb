class Source < ApplicationRecord
  include NameSearchable

  belongs_to :user
  has_many :recipes, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }

  normalizes :name, with: ->(name) { name.strip }
end
