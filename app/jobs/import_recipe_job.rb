# Reads an imported recipe into its Draft in the background, so the user never waits on a page or Claude.
class ImportRecipeJob < ApplicationJob
  queue_as :default

  # Claude rate limits and outages are worth waiting out; after the last attempt the draft shows the failure.
  retry_on CleanRecipeService::TemporaryError, wait: :polynomially_longer, attempts: 5 do |job, _error|
    draft, locale = job.arguments
    I18n.with_locale(locale || I18n.default_locale) { draft.update!(status: :failed, failure_reason: :cleanup_failed) }
  end

  # The draft was discarded before it was read.
  discard_on ActiveJob::DeserializationError

  # locale: the user's language, for the live updates the draft broadcasts while it's read.
  def perform(draft, locale = I18n.default_locale.to_s)
    I18n.with_locale(locale) { ImportRecipeService.new(draft).call }
  end
end
