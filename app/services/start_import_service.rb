# Starts an Import (GLOSSARY): checks the recipe link, pasted text or screenshots, puts a Draft in the user's Draft
# box as Reading…, and queues ImportRecipeJob to read it in the background. The import form uses it, and so will the
# phone API.
class StartImportService
  # Imports a user can start in an hour, from the import form and the assistant together: each can cost a Claude call.
  HOURLY_LIMIT = 20
  # An admin (the app's owner) imports more.
  ADMIN_HOURLY_LIMIT = 50
  # From this many left, the import page shows the count in amber.
  FEW_LEFT = 5

  # error: :blank, :invalid_link, :too_long (pasted text), :needs_claude, :already_saved (with the recipe),
  # :already_in_draft_box, :rate_limited, or for screenshots :title_blank, :too_many_screenshots or
  # :unreadable_screenshot
  Result = Data.define(:draft, :error, :recipe) do
    def success? = error.nil?
  end

  # How many more imports the user can start this hour (shown on the import page).
  def self.hourly_limit(user) = user.admin? ? ADMIN_HOURLY_LIMIT : HOURLY_LIMIT

  def self.imports_left(user) = [ hourly_limit(user) - Rails.cache.read(counter_key(user), raw: true).to_i, 0 ].max

  def self.counter_key(user) = "imports:#{user.id}"

  # An import that failed before Claude read anything (ImportRecipeService) cost nothing, so it's given back. Only
  # while the hour it was counted in is still running: an expired counter isn't taken below zero.
  def self.give_back(user)
    key = counter_key(user)
    Rails.cache.decrement(key, 1) if Rails.cache.read(key, raw: true).to_i.positive?
  end

  # title and screenshots: pictures of one recipe (e.g. an AI's summary of a 小红书 video), named by the user, since
  # the pictures don't say which recipe they are. draft: a failed draft to read again (Try again), from its own link,
  # pasted text or screenshots.
  def initialize(user:, url: nil, text: nil, title: nil, screenshots: [], draft: nil)
    @user = user
    @draft = draft
    @url = RecipeLink.normalize(draft ? draft.source_url : url)
    # Browsers send line breaks as \r\n; as \n, the text is as long as the paste box counted it.
    @text = (draft ? draft.source_text : text).to_s.gsub("\r\n", "\n").strip.presence
    @title = title.to_s.squish.presence
    @screenshots = screenshots
  end

  def call
    return screenshots_again if @draft&.screenshot_count&.positive?
    return failure(:blank) if @url.nil? && @text.nil? && @screenshots.empty?
    return failure(:needs_claude) if (@text || @screenshots.any?) && !CleanRecipeService.available?
    return from_screenshots if @screenshots.any?

    recipe = @url && @user.recipes.find_by(source_url: @url)
    return failure(:already_saved, recipe: recipe) if recipe

    draft = draft_to_read
    return failure(:already_in_draft_box) unless draft
    return failure(invalid(draft)) unless draft.valid?

    start(draft)
  rescue ActiveRecord::RecordNotUnique
    failure(:already_in_draft_box)
  end

  private

  def start(draft)
    return failure(:rate_limited) if over_hourly_limit?
    return failure(invalid(draft)) unless draft.save

    # The job renders live updates for this user, in the language they imported in.
    ImportRecipeJob.perform_later(draft, I18n.locale.to_s)
    Result.new(draft: draft, error: nil, recipe: nil)
  end

  # The user's name for the recipe shows in the Draft box while it's read, and stays its name.
  def from_screenshots
    return failure(:title_blank) unless @title
    return failure(:too_many_screenshots) if @screenshots.size > Draft::MAX_SCREENSHOTS
    # Checked before they're read into memory
    return failure(:unreadable_screenshot) if @screenshots.any? { |file| file.size > DraftImage::MAX_BYTES }

    images = @screenshots.map.with_index(1) { |file, position| DraftImage.from_upload(file, position: position) }
    draft = @user.drafts.new(data: { "name" => @title }, screenshot_count: images.size, images: images)
    draft.valid? ? start(draft) : failure(:unreadable_screenshot)
  end

  # A failed draft from screenshots, read again from the screenshots it kept, under the user's name for it
  def screenshots_again
    return failure(:already_in_draft_box) unless @draft.failed?
    return failure(:needs_claude) unless CleanRecipeService.available?

    @draft.assign_attributes(status: :reading, failure_reason: nil, data: { "name" => @draft.name })
    start(@draft)
  end

  # The draft being tried again, or a failed draft for the same link (typically read again with the recipe text pasted
  # in); any other draft for that link means it's already being imported.
  def draft_to_read
    existing = @draft || (@url && @user.drafts.find_by(source_url: @url))
    return @user.drafts.new(source_url: @url, source_text: @text) unless existing
    return unless existing.failed?

    existing.tap { |draft| draft.assign_attributes(status: :reading, failure_reason: nil, source_text: @text, data: {}) }
  end

  # :taken means another request for the same link just won the race.
  def invalid(draft)
    if draft.errors.of_kind?(:source_text, :too_long) then :too_long
    elsif draft.errors.of_kind?(:source_url, :taken) then :already_in_draft_box
    else :invalid_link
    end
  end

  # Counted in Rails.cache (Redis), so the web and worker processes share it. Every import started counts, so
  # discarding drafts or reading a failed one again doesn't free any up; only one that failed before Claude read it
  # is given back (give_back).
  def over_hourly_limit?
    Rails.cache.increment(self.class.counter_key(@user), 1, expires_in: 1.hour).to_i > self.class.hourly_limit(@user)
  end

  def failure(error, recipe: nil) = Result.new(draft: nil, error: error, recipe: recipe)
end
