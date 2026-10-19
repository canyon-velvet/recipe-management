# Writes the assistant's reply in the background, streaming it into the panel. Not retried (Active Job retries only
# what retry_on names): a chat reply that failed is shown as failed, and the user can simply ask again.
class WriteReplyJob < ApplicationJob
  queue_as :default

  # The conversation was deleted before the reply was written.
  discard_on ActiveJob::DeserializationError

  # locale: the user's language, for the messages the reply may show (e.g. "something went wrong").
  def perform(reply, locale = I18n.default_locale.to_s)
    I18n.with_locale(locale) { WriteReplyService.new(reply).call }
  end
end
