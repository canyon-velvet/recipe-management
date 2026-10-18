module Assistant
  # Sending a message from the panel: the user's message and the assistant's pending reply are added to the chat,
  # and WriteReplyJob streams the reply into it.
  class MessagesController < BaseController
    def create
      content = params.expect(message: [ :content ])[:content]
      # Checked and saved under the user's lock, so messages sent at once can't all slip in under the limit
      question, reply = current_user.with_lock do
        current_user.current_conversation!.ask(content) unless current_user.assistant_limit_reached?
      end
      return render_limit_notice unless question
      return head :unprocessable_entity unless reply

      WriteReplyJob.perform_later(reply, I18n.locale.to_s)
      render turbo_stream: [
        turbo_stream.append("assistant_messages", partial: "assistant/messages/message",
                                                  collection: [ question, reply ], as: :message),
        limit_strip
      ]
    end

    private

    # Over the daily limit nothing is saved or sent to Claude. The notice is shown in the chat, and the 429 keeps
    # what was typed in the box.
    def render_limit_notice
      render turbo_stream: [ turbo_stream.append("assistant_messages", partial: "assistant/messages/limit_notice"),
                             limit_strip ],
             status: :too_many_requests
    end

    # How many messages are left, redrawn after each one sent (the panel itself stays as it was across pages)
    def limit_strip = turbo_stream.replace("assistant_limit", partial: "assistant/messages/limit_strip",
                                                              locals: { user: current_user })
  end
end
