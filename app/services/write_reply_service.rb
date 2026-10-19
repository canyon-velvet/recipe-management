# Writes the assistant's pending reply (WriteReplyJob runs this in the background). The router reads the conversation
# and either answers itself or hands it to a specialist, which writes the reply instead (see Assistant::Router). Each
# agent's turn is run by RunAgentService, which streams the text into the user's open panel; then the reply is saved.
# Each attempt is recorded as a Run. If Claude fails, the reply is marked failed so the panel shows an error instead
# of "Thinking…" forever.
class WriteReplyService
  # How much of the conversation Claude reads.
  CONTEXT_MESSAGES = 20

  def initialize(reply, client: nil)
    @reply = reply
    @client = client
  end

  def call
    return unless @reply.pending?
    # A pending reply that already has a run was interrupted: Solid Queue puts back a job still running when it shuts
    # down, and the stop skips the rescues below. Ending it as failed beats "Thinking…" forever; the user can ask again.
    if @reply.run
      @run = @reply.run
      return fail_reply("interrupted")
    end

    conversation = @reply.conversation
    question = @reply.question&.content
    agent = Assistant::Router.new(conversation.user, last_agent: conversation.last_agent, question: question)
    @run = @reply.create_run!(model: agent.model)
    responses = run(agent)
    if (specialist = agent.handoff(responses.last))
      # The specialist carries on the router's Turn, keeping what the router did, such as suggesting a preference.
      agent = specialist.new(conversation.user, question: question, turn: agent.turn)
      @run.update!(model: agent.model)
      # Anything the router wrote before handing over is dropped, and the panel goes back to "Thinking…".
      @reply.tap { _1.content = "" }.broadcast_to_panel
      responses = run(agent)
    end
    save(agent, responses)
  rescue Anthropic::Errors::APIError => e
    fail_reply(e)
  rescue StandardError => e
    # Anything unexpected still ends the reply, so the panel doesn't wait forever; the error is reported.
    Rails.error.report(e, handled: true, context: { message_id: @reply.id })
    fail_reply(e)
  end

  private

  def client = @client ||= Anthropic::Client.new(api_key: CleanRecipeService.api_key)

  # Runs the agent's turn. The reply records who wrote it, even if it fails.
  def run(agent)
    @agent = agent
    @reply.agent = agent.name
    context = @context ||= @reply.conversation.context(CONTEXT_MESSAGES + 1)
    RunAgentService.new(agent, reply: @reply, run: @run, context: context, client: client).call
  end

  def save(agent, responses)
    text = responses.map { |response| final_text(response) }.compact_blank.join("\n\n")
    cards = agent.shown_cards
    @reply.draft_ids = agent.turn.draft_ids

    if responses.last.stop_reason == :refusal
      finish(I18n.t("assistant.declined"))
      @run.fail!("refusal: #{responses.last.stop_details&.category}")
    elsif text.blank? && cards.empty? && @reply.draft_ids.empty? && agent.turn.suggestions.empty?
      # An empty reply would be sent back as history, which the API rejects, breaking the rest of the chat.
      fail_reply("empty reply")
    else
      # Cards say enough on their own (a recipe's has its reason, a draft's its status, a suggestion its fact), so a
      # reply can be just them.
      @reply.cards = cards
      @reply.preference_suggestions = agent.turn.suggestions
      finish(text)
      @run.succeed!
    end
  end

  # A response's text. If the model declined part-way and a fallback model took over, only the fallback's answer
  # counts: the text before the last fallback block was abandoned.
  def final_text(response)
    blocks = response.content
    last_fallback = blocks.rindex { |block| block.type == :fallback }
    blocks.drop(last_fallback ? last_fallback + 1 : 0).select { |block| block.type == :text }.map(&:text).join
  end

  def finish(content)
    @reply.update!(content: content, status: :done)
    @reply.broadcast_to_panel
  end

  def fail_reply(error)
    message = error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error
    # Imports the agent started go on, so their cards stay under the error.
    @reply.draft_ids = @agent.turn.draft_ids if @agent
    @reply.update!(status: :failed)
    @run&.fail!(message)
    @reply.broadcast_to_panel
  end
end
