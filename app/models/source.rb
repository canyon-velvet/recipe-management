class Source < ApplicationRecord
  include NameSearchable

  belongs_to :user
  has_many :recipes, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }, length: { maximum: 200 }

  normalizes :name, with: ->(name) { name.strip }
end
