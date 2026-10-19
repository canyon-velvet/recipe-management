# A recipe produced by an import that the user hasn't saved yet. It waits in the Draft box until the
# user reviews and saves it as a Recipe, or discards it.
#
# `data` is what the importer read, in this shape:
#   { "name" => "…", "description" => "…", "source_name" => "…",
#     "ingredients" => [{ "name" => "…", "quantity" => "…", "unit" => "…", "aisle_id" => 1 }],
#     "steps" => ["…"], "tags" => ["tag_key"], "tips" => ["…"],
#     "servings" => 4, "prep_minutes" => 15, "cook_minutes" => 30, "total_minutes" => 45 }
#   (servings and the minutes, Recipe::COUNT_LIMITS, are nil when the source doesn't say)
class Draft < ApplicationRecord
  include DraftBoxBroadcasts
  include HasRecipeLink

  # Pasted text is sent to Claude, so it gets the same cap as a page's text.
  MAX_SOURCE_TEXT = ExtractRecipeService::MAX_TEXT_CHARS
  # Screenshots read together as one recipe
  MAX_SCREENSHOTS = 6

  belongs_to :user
  # An import from screenshots: kept until Claude has read them (ImportRecipeService). Its name is the user's, in data.
  has_many :images, -> { order(:position) }, class_name: "DraftImage", dependent: :delete_all, inverse_of: :draft

  enum :status, { reading: "reading", ready: "ready", failed: "failed" }, validate: true

  validates :source_text, length: { maximum: MAX_SOURCE_TEXT }
  validate :data_must_be_an_object

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def name = data["name"].to_s.strip.presence

  # The link passed validation, but Ruby's stricter URI parser can still reject a few such strings.
  def source_host
    URI.parse(source_url).host if source_url
  rescue URI::InvalidURIError
    nil
  end

  # Until the recipe is read: a readable form of the link, or the first line of pasted text.
  def title = name || RecipeLink.title(source_url) || source_url || pasted_title || I18n.t("drafts.pasted_text")

  # Why it failed, in the language in use. Unknown or missing reasons show the generic message.
  def failure_message
    key = failure_reason.present? && I18n.exists?(failure_reason, scope: "drafts.failures") ? failure_reason : "generic"
    I18n.t(key, scope: "drafts.failures")
  end

  private

  def pasted_title = source_text.to_s.lines.map(&:strip).find(&:present?)&.truncate(60)

  def data_must_be_an_object
    errors.add(:data, :invalid) unless data.is_a?(Hash)
  end
end
