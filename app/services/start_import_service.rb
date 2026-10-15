# Starts an Import (GLOSSARY): checks the recipe link or pasted text, puts a Draft in the user's Draft box as
# Reading…, and queues ImportRecipeJob to read it in the background. The import form uses it, and so will the
# phone API.
class StartImportService
  # Imports a user can start in an hour, from the import form and the assistant together: each can cost a Claude call.
  HOURLY_LIMIT = 20

  # error: :blank, :invalid_link, :too_long (pasted text), :needs_claude, :already_saved (with the recipe),
  # :already_in_draft_box or :rate_limited
  Result = Data.define(:draft, :error, :recipe) do
    def success? = error.nil?
  end

  def initialize(user:, url: nil, text: nil)
    @user = user
    @url = RecipeLink.normalize(url)
    @text = text.to_s.strip.presence
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

  # A failed draft for the same link is read again (typically with the recipe text pasted in); any other draft
  # for that link means it's already being imported.
  def draft_to_read
    existing = @url && @user.drafts.find_by(source_url: @url)
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
  # discarding drafts or reading a failed one again doesn't free any up.
  def over_hourly_limit?
    Rails.cache.increment("imports:#{@user.id}", 1, expires_in: 1.hour).to_i > HOURLY_LIMIT
  end

  def failure(error, recipe: nil) = Result.new(draft: nil, error: error, recipe: recipe)
end
