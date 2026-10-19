# Reads one Reading… Draft (ImportRecipeJob runs this in the background): fetches and extracts the page unless the
# recipe text was pasted or it's from screenshots, has Claude clean it up, and leaves the draft Ready with its data, or
# Failed with the reason. Screenshots are deleted once read; a failed draft keeps them, to be read again. Without an Anthropic API key, a page's structured recipe is used as it is.
class ImportRecipeService
  # Failures before Claude read anything (the page wouldn't open or blocked us, or there's no Claude to read it): the
  # import cost nothing, so its count is given back to the user.
  UNREAD_FAILURES = %i[blocked fetch_failed needs_claude].freeze

  def initialize(draft)
    @draft = draft
  end

  def call
    return unless @draft.reading?

    extracted = fetch_and_extract if @draft.source_text.blank? && !screenshots?
    show_title(extracted&.title)
    data = CleanRecipeService.available? ? cleaned(extracted) : structured(extracted)
    data["name"] = @draft.name if screenshots? # the user's name for it
    data["source_name"] = extracted&.site_name || RecipeLink.site_name(@draft.source_url)
    @draft.update!(status: :ready, data: data, failure_reason: nil)
    @draft.images.delete_all
  rescue ImportFailure => e
    @draft.update!(status: :failed, failure_reason: e.reason)
    StartImportService.give_back(@draft.user) if UNREAD_FAILURES.include?(e.reason)
  rescue CleanRecipeService::TemporaryError
    raise # ImportRecipeJob retries these
  rescue StandardError => e
    # Anything unexpected fails the draft (shown with the generic reason) instead of leaving it Reading… while the
    # job is retried for weeks. The error is still reported.
    Rails.error.report(e, handled: true, context: { draft_id: @draft.id })
    @draft.update!(status: :failed, failure_reason: :unexpected)
  end

  private

  # Fetching takes a second; Claude takes several. Showing the page's title meanwhile tells drafts apart.
  def show_title(title)
    @draft.update!(data: @draft.data.merge("name" => title)) if title.present? && @draft.name.blank?
  end

  def screenshots? = @draft.screenshot_count.positive?

  def fetch_and_extract
    ExtractRecipeService.new(FetchPageService.new(@draft.source_url).call, url: @draft.source_url).call
  end

  def cleaned(extracted)
    text = @draft.source_text.presence || extracted&.text
    images = @draft.images.map { |image| { media_type: image.content_type, data: image.data } }
    without_images(CleanRecipeService.new(user: @draft.user, recipe: extracted&.recipe, text: text, images: images).call)
  end

  # Without Claude, ingredient lines stay whole (e.g. "1 cup oats") and land in Other; the review form fixes the rest.
  def structured(extracted)
    raise ImportFailure.new(:needs_claude) unless extracted&.complete?

    recipe = extracted.recipe
    without_images(
      "name" => recipe[:name].to_s,
      "description" => recipe[:description].to_s,
      "ingredients" => recipe[:ingredients].map { |line| { "name" => line } },
      "steps" => recipe[:steps],
      "tags" => [],
      **Recipe::COUNT_LIMITS.keys.to_h { |key| [ key.to_s, recipe[key] ] }
    )
  end

  # Descriptions and steps are shown as markdown; an image in imported text would load from someone else's server
  # every time the recipe is viewed.
  def without_images(data)
    strip = ->(text) { text.to_s.gsub(/!\[[^\]]*\]\([^)]*\)/, "").strip }
    data.merge("description" => strip.(data["description"]), "steps" => data["steps"].map(&strip).compact_blank,
               "tips" => Array(data["tips"]).map(&strip).compact_blank)
  end
end
