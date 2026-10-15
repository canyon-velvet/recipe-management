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

  # Pasted text is sent to Claude, so it gets the same cap as a page's text.
  MAX_SOURCE_TEXT = ExtractRecipeService::MAX_TEXT_CHARS

  belongs_to :user

  enum :status, { reading: "reading", ready: "ready", failed: "failed" }, validate: true

  validates :source_url, http_url: true, allow_blank: true
  validates :source_url, uniqueness: { scope: :user_id }, allow_nil: true
  validates :source_text, length: { maximum: MAX_SOURCE_TEXT }
  validate :data_must_be_an_object

  normalizes :source_url, with: ->(url) { RecipeLink.normalize(url) }

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

  # Unknown or missing reasons show the generic message.
  def failure_reason_key = failure_reason.presence || "generic"

  private

  def pasted_title = source_text.to_s.lines.map(&:strip).find(&:present?)&.truncate(60)

  def data_must_be_an_object
    errors.add(:data, :invalid) unless data.is_a?(Hash)
  end
end
