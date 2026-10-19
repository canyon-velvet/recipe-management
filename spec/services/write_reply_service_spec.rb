require "rails_helper"

RSpec.describe WriteReplyService do
  let(:conversation) { create(:conversation) }
  let(:reply) { conversation.ask("What can I make with eggs?").last }

  def write(client) = described_class.new(reply, client: client).call

  it "streams the reply, saves it and records the run and the router's step" do
    client = FakeClaude.new([ "Try ", "a **tomato ", "and egg** stir-fry." ])

    write(client)

    expect(reply.reload).to have_attributes(status: "done", content: "Try a **tomato and egg** stir-fry.")
    expect(reply.run).to have_attributes(status: "succeeded", model: "claude-haiku-4-5", input_tokens: 120,
                                         output_tokens: 3, error: nil)
    expect(reply.run.finished_at).to be_present
    expect(reply.run.steps.sole).to have_attributes(name: "router", model: "claude-haiku-4-5", input_tokens: 120,
                                                    output_tokens: 3, error: nil)
    expect(reply.run.steps.sole.finished_at).to be_present
  end

  it "sends the recent finished messages, starting with the user's, to the router" do
    earlier = conversation.ask("Hi").last
    earlier.update!(content: "Hello! What are we cooking?", status: :done)
    failed = conversation.ask("Anything?").last
    failed.update!(status: :failed)
    client = FakeClaude.new([ "Eggs!" ])

    write(client)

    request = client.requests.sole
    expect(request[:messages]).to eq [
      { role: "user", content: "Hi" },
      { role: "assistant", content: "Hello! What are we cooking?" },
      { role: "user", content: "Anything?" },
      { role: "user", content: "What can I make with eggs?" }
    ]
    expect(request[:model]).to eq "claude-haiku-4-5"
    expect(request[:system_]).to include("language of the user's latest message", "can't take actions in the app yet")
  end

  it "reads only the last messages of a long chat" do
    25.times { |i| conversation.messages.create!(role: :user, content: "Message #{i}") }
    client = FakeClaude.new([ "OK" ])

    write(client)

    messages = client.requests.sole[:messages]
    expect(messages.size).to be <= WriteReplyService::CONTEXT_MESSAGES
    expect(messages.last).to eq(role: "user", content: "What can I make with eggs?")
  end

  it "shows the reply in the user's open panel as it streams" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    stub_const("RunAgentService::BROADCAST_INTERVAL", 0)

    write(FakeClaude.new([ "Eggs ", "and ", "rice." ]))

    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
      .with([ conversation.user, :assistant ], hash_including(target: reply)).at_least(4).times
  end

  it "marks the reply failed, not Thinking… forever, when Claude errors part-way" do
    error = Anthropic::Errors::APIConnectionError.new(url: URI("https://api.anthropic.com/v1/messages"))

    write(FakeClaude.new([ "Try " ], error: error))

    expect(reply.reload.status).to eq "failed"
    error = "Anthropic::Errors::APIConnectionError: Connection error."
    expect(reply.run).to have_attributes(status: "failed", error: error)
    expect(reply.run.steps.sole).to have_attributes(error: error, finished_at: be_present)
  end

  it "says it can't help when the model declines" do
    write(FakeClaude.new([], stop_reason: :refusal))

    expect(reply.reload).to have_attributes(status: "done", content: "Sorry, I can't help with that one.")
    expect(reply.run).to have_attributes(status: "failed", error: "refusal: cyber")
  end

  it "fails an empty reply instead of saving it, and never sends an empty message back" do
    write(FakeClaude.new([ "  " ]))
    expect(reply.reload.status).to eq "failed"
    expect(reply.run.error).to eq "empty reply"

    # Even an empty finished message from before (e.g. older data) is left out of the history.
    reply.update!(status: :done, content: "")
    next_reply = conversation.ask("Next?").last
    client = FakeClaude.new([ "Sure." ])
    described_class.new(next_reply, client: client).call

    expect(client.requests.sole[:messages].pluck(:content)).to eq [ "What can I make with eggs?", "Next?" ]
  end

  it "ends an interrupted reply as failed when its job runs again, instead of Thinking… forever" do
    interrupted = Class.new(Interrupt) # like a job stopped at shutdown: not a StandardError, so no rescue catches it
    expect { write(FakeClaude.new([ "Half an ans" ], error: interrupted.new)) }.to raise_error(interrupted)
    expect(reply.reload).to have_attributes(status: "pending")

    client = FakeClaude.new([ "Second answer." ])
    described_class.new(Message.find(reply.id), client: client).call # the re-queued copy

    expect(client.requests).to be_empty
    expect(reply.reload.status).to eq "failed"
    expect(reply.run).to have_attributes(status: "failed", error: "interrupted")
    expect(reply.run.steps.sole).to have_attributes(error: "interrupted", finished_at: be_present)
  end

  describe "handing off to the Recommend specialist" do
    let(:user) { conversation.user }
    let!(:tofu) { create(:recipe, user: user, name: "Mapo tofu") }
    let(:transfer) { { name: "transfer_to_recommend", input: {} } }
    let(:show_tofu) { { name: "show_recipes", input: { recipes: [ { id: tofu.id, why: "Spicy." } ] } } }

    it "searches the user's recipes, answers with the ones it recommends and shows them as cards" do
      client = FakeClaude.new([ "Let me hand you over." ], tool_uses: [ transfer ])
                         .and_then([ "I'll search." ], tool_uses: [ { name: "search_recipes", input: { name: "tofu" } } ])
                         .and_then([ "Try the **Mapo tofu**." ], tool_uses: [ show_tofu ])
                         .and_then([])

      write(client)

      expect(reply.reload).to have_attributes(status: "done", agent: "recommend", recipe_ids: [ tofu.id ],
                                              card_reasons: { tofu.id.to_s => "Spicy." },
                                              content: "I'll search.\n\nTry the **Mapo tofu**.")
      expect(reply.run).to have_attributes(status: "succeeded", model: "claude-sonnet-5-5", input_tokens: 480,
                                           output_tokens: 3)
      expect(reply.run.steps.map { [ _1.name, _1.model ] }).to eq [
        [ "router", "claude-haiku-4-5" ], [ "recommend", "claude-sonnet-5-5" ], [ "search_recipes", nil ],
        [ "recommend", "claude-sonnet-5-5" ], [ "show_recipes", nil ], [ "recommend", "claude-sonnet-5-5" ]
      ]
      expect(reply.run.steps.third).to have_attributes(input: { "name" => "tofu" }, finished_at: be_present)
      expect(reply.run.steps.third.output["recipes"].sole).to include("id" => tofu.id, "name" => "Mapo tofu")
    end

    it "offers to save a preference the user mentions, without saving it" do
      suggest = { name: "suggest_preference", input: { category: "avoid", value: "peanut" } }
      client = FakeClaude.new(tool_uses: [ transfer ])
                         .and_then(tool_uses: [ suggest ])
                         .and_then([ "Here's a peanut-free idea." ])

      write(client)

      expect(reply.reload.preference_suggestions)
        .to eq [ { "category" => "avoid", "value" => "peanut", "replaces" => nil, "state" => "pending" } ]
      expect(user.preferences).to be_empty
    end

    it "keeps a preference the router suggested as it handed over" do
      suggest = { name: "suggest_preference", input: { category: "diet", value: "vegetarian" } }
      client = FakeClaude.new(tool_uses: [ suggest, transfer ]).and_then([ "Try the tofu." ])

      write(client)

      expect(reply.reload.preference_suggestions.pluck("value")).to eq [ "vegetarian" ]
      expect(reply.run.steps.pluck(:name)).to eq %w[router suggest_preference recommend]
    end

    it "suggests at most 3 facts per reply, counting the router's and the specialist's together" do
      suggest = ->(value) { { name: "suggest_preference", input: { category: "likes", value: value } } }
      client = FakeClaude.new(tool_uses: [ suggest.("tofu"), suggest.("rice"), transfer ])
                         .and_then(tool_uses: [ suggest.("noodles"), suggest.("eggs") ])
                         .and_then([ "Noted." ])

      write(client)

      expect(reply.reload.preference_suggestions.pluck("value")).to eq %w[tofu rice noodles]
    end

    it "saves a reply that's only cards, as each card says why" do
      client = FakeClaude.new(tool_uses: [ transfer ])
                         .and_then(tool_uses: [ { name: "get_recipe", input: { id: tofu.id } } ])
                         .and_then(tool_uses: [ show_tofu ])
                         .and_then([])

      write(client)

      expect(reply.reload).to have_attributes(status: "done", content: "", recipe_ids: [ tofu.id ])
    end

    it "shows no cards when the specialist declines in the end" do
      client = FakeClaude.new(tool_uses: [ transfer ])
                         .and_then(tool_uses: [ { name: "get_recipe", input: { id: tofu.id } } ])
                         .and_then(tool_uses: [ show_tofu ])
                         .and_then([], stop_reason: :refusal)

      write(client)

      expect(reply.reload).to have_attributes(content: "Sorry, I can't help with that one.", recipe_ids: [],
                                              card_reasons: {})
    end

    it "keeps follow-ups with the specialist, and notes the cards it showed" do
      earlier = conversation.ask("Something with tofu?").last
      earlier.update!(content: "Try this.", status: :done, agent: :recommend, cards: { tofu.id => "Spicy." })
      followup = conversation.ask("How spicy is it?").last
      client = FakeClaude.new([ "Quite." ])

      described_class.new(followup, client: client).call

      request = client.requests.sole
      expect(request[:system_]).to include("The last reply in this chat came from the Recommend specialist")
      cards = "(Recipe cards shown: Mapo tofu (id #{tofu.id}): Spicy.)"
      expect(request[:messages]).to include(role: "assistant", content: "Try this.\n\n#{cards}")
      expect(followup.reload.agent).to eq "router"
    end
  end

  describe "handing off to the Import specialist" do
    let(:link) { "https://example.com/mapo-tofu" }
    let(:reply) { conversation.ask("Can you import #{link}?").last }

    it "imports the link from the user's message into their Draft box, on Haiku" do
      client = FakeClaude.new(tool_uses: [ { name: "transfer_to_import", input: {} } ])
                         .and_then(tool_uses: [ { name: "import_recipe", input: { url: link } } ])
                         .and_then([ "Importing it now; you'll get a notification when it's ready." ])

      expect { write(client) }.to have_enqueued_job(ImportRecipeJob)

      expect(reply.reload).to have_attributes(status: "done", agent: "import",
                                              content: "Importing it now; you'll get a notification when it's ready.")
      expect(reply.run.model).to eq "claude-haiku-4-5"
      expect(client.requests.second[:tools].pluck(:name)).to eq %w[import_recipe list_drafts show_recipes]
      expect(conversation.user.drafts.sole.source_url).to eq link
      expect(reply.draft_ids).to eq [ conversation.user.drafts.sole.id ] # its card under the reply
    end

    it "keeps the draft's card when the reply fails after the import started, or says nothing more" do
      error = Anthropic::Errors::APIConnectionError.new(url: URI("https://api.anthropic.com/v1/messages"))
      client = FakeClaude.new(tool_uses: [ { name: "transfer_to_import", input: {} } ])
                         .and_then(tool_uses: [ { name: "import_recipe", input: { url: link } } ])
                         .and_then([], error: error)

      write(client)

      expect(reply.reload).to have_attributes(status: "failed", draft_ids: [ conversation.user.drafts.sole.id ])

      quiet = conversation.ask("And https://example.com/stew").last
      client = FakeClaude.new(tool_uses: [ { name: "transfer_to_import", input: {} } ])
                         .and_then(tool_uses: [ { name: "import_recipe", input: { url: "https://example.com/stew" } } ])
                         .and_then([])

      described_class.new(quiet, client: client).call

      expect(quiet.reload).to have_attributes(status: "done", content: "", draft_ids: [ be_a(Integer) ])
    end
  end

  it "doesn't pin when the router wrote the last reply" do
    client = FakeClaude.new([ "Eggs!" ])

    write(client)

    expect(client.requests.sole[:system_]).not_to include("The last reply in this chat")
    expect(reply.reload.agent).to eq "router"
  end

  it "leaves a reply that's already written alone" do
    reply.update!(status: :done, content: "Done already")
    client = FakeClaude.new([ "Again" ])

    write(client)

    expect(client.requests).to be_empty
    expect(reply.reload.content).to eq "Done already"
  end
end
