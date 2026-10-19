# Starts an Import (GLOSSARY): checks the recipe link or pasted text, puts a Draft in the user's Draft box as
# Reading…, and queues ImportRecipeJob to read it in the background. The import form uses it, and so will the
# phone API.
class StartImportService
  # Imports a user can start in an hour, from the import form and the assistant together: each can cost a Claude call.
  HOURLY_LIMIT = 20
  # An admin (the app's owner) imports more.
  ADMIN_HOURLY_LIMIT = 50
  # From this many left, the import page shows the count in amber.
  FEW_LEFT = 5

  # error: :blank, :invalid_link, :too_long (pasted text), :needs_claude, :already_saved (with the recipe),
  # :already_in_draft_box or :rate_limited
  Result = Data.define(:draft, :error, :recipe) do
    def success? = error.nil?
  end

  def self.hourly_limit(user) = user.admin? ? ADMIN_HOURLY_LIMIT : HOURLY_LIMIT

  # How many more imports the user can start this hour (shown on the import page).
  def self.imports_left(user) = [ hourly_limit(user) - Rails.cache.read(counter_key(user), raw: true).to_i, 0 ].max

  def self.counter_key(user) = "imports:#{user.id}"

  def self.given_back_key(user) = "imports_given_back:#{user.id}"

  # An import that failed before Claude read anything (ImportRecipeService) cost nothing, so it's given back: up to an
  # hour's limit of them an hour, so Try again on a link that never opens can't fetch pages on and on. The counters
  # run for an hour from their first count, so a failure counted near the end of one hour may be given back to the
  # next. An expired counter isn't taken below zero, and one that expires just as it's counted down lasts an hour, not
  # the store's default week.
  def self.give_back(user)
    key = counter_key(user)
    return unless Rails.cache.read(key, raw: true).to_i.positive?
    return if Rails.cache.increment(given_back_key(user), 1, expires_in: 1.hour).to_i > hourly_limit(user)

    Rails.cache.decrement(key, 1, expires_in: 1.hour)
  end

  # draft: a failed draft to read again (Try again), from its own link or pasted text.
  def initialize(user:, url: nil, text: nil, draft: nil)
    @user = user
    @draft = draft
    @url = RecipeLink.normalize(draft ? draft.source_url : url)
    # Browsers send line breaks as \r\n; as \n, the text is as long as the paste box counted it.
    @text = (draft ? draft.source_text : text).to_s.gsub("\r\n", "\n").strip.presence
  end

  def call
    return failure(:blank) if @url.nil? && @text.nil?
    return failure(:needs_claude) if @text && !CleanRecipeService.available?

    recipe = @url && @user.recipes.find_by(source_url: @url)
    return failure(:already_saved, recipe: recipe) if recipe

    draft = draft_to_read
    return failure(:already_in_draft_box) unless draft
    return failure(invalid(draft)) unless draft.valid?
    return failure(:rate_limited) if over_hourly_limit?
    return failure(invalid(draft)) unless draft.save

    # The job renders live updates for this user, in the language they imported in.
    ImportRecipeJob.perform_later(draft, I18n.locale.to_s)
    Result.new(draft: draft, error: nil, recipe: nil)
  rescue ActiveRecord::RecordNotUnique
    failure(:already_in_draft_box)
  end

  private

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
  # is given back (give_back). One refused here is taken back off, so it doesn't use up a place.
  def over_hourly_limit?
    key = self.class.counter_key(@user)
    return false if Rails.cache.increment(key, 1, expires_in: 1.hour).to_i <= self.class.hourly_limit(@user)

    Rails.cache.decrement(key, 1, expires_in: 1.hour)
    true
  end

  def failure(error, recipe: nil) = Result.new(draft: nil, error: error, recipe: recipe)
end
