# The link to the recipe's page (source_url), kept the same way by a Recipe and a Draft: http(s) only, once per user,
# and in one canonical form per page, so the same link can't be saved twice in different spellings. StartImportService
# matches an import's link against both.
module HasRecipeLink
  extend ActiveSupport::Concern

  included do
    validates :source_url, http_url: true, allow_blank: true
    validates :source_url, uniqueness: { scope: :user_id }, allow_nil: true

    normalizes :source_url, with: ->(url) { RecipeLink.normalize(url) }
  end
end
