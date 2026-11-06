require "rails_helper"

RSpec.describe Message do
  def count_queries(&)
    count = 0
    # Not Rails' one-off look-ups of a table's columns, which depend on what ran before
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end

  it "only takes the known roles and statuses, in the model and the database" do
    expect(build(:message, role: "system")).not_to be_valid
    expect(build(:message, status: "lost")).not_to be_valid
  end

  it "lets an assistant reply start empty" do
    expect(build(:message, role: "assistant", content: "", status: "pending")).to be_valid
  end

  it "only takes the known agents" do
    expect(build(:message, role: "assistant", agent: "chef")).not_to be_valid
    expect(build(:message, role: "assistant", agent: "recommend")).to be_valid
  end

  it "knows the user's message a reply answers" do
    conversation = create(:conversation)
    conversation.ask("First?").last.update!(status: :done, content: "One.")
    question, reply = conversation.ask("Second?")
    conversation.ask("Third?")

    expect(reply.question).to eq question
  end

  describe "#drafts" do
    it "is the drafts a reply imported, in order, leaving out ones saved or discarded since and other users'" do
      conversation = create(:conversation)
      user = conversation.user
      first, second, discarded = %w[a b c].map { |path| user.drafts.create!(source_url: "https://example.com/#{path}") }
      someone_elses = create(:user).drafts.create!(source_url: "https://example.com/d")
      reply = create(:message, conversation: conversation, role: "assistant",
                               draft_ids: [ second.id, discarded.id, someone_elses.id, first.id ])
      discarded.destroy!

      expect(reply.drafts).to eq [ second, first ]
      expect(Message.load_cards([ reply ], user).sole.drafts).to eq [ second, first ]
    end
  end

  describe "#recipes" do
    it "is the recipes shown under the reply, in the order shown, leaving out deleted ones and other users'" do
      conversation = create(:conversation)
      tofu, noodles, deleted = create_list(:recipe, 3, user: conversation.user)
      someone_elses = create(:recipe)
      reply = create(:message, conversation: conversation, role: "assistant",
                               recipe_ids: [ noodles.id, deleted.id, someone_elses.id, tofu.id ])
      deleted.destroy!

      expect(reply.recipes).to eq [ noodles, tofu ]
      expect(create(:message, conversation: conversation).recipes).to eq []

      # The panel loads every message's cards in one go
      question = create(:message, conversation: conversation)
      # recipes, recipe_ingredients (and their ingredients, when there are any)
      expect(count_queries { Message.load_cards([ reply, question ], conversation.user) }).to eq 2
      expect(count_queries { expect([ reply.recipes, question.recipes ]).to eq [ [ noodles, tofu ], [] ] }).to eq 0
    end
  end

  describe "database constraints" do
    let(:conversation) { create(:conversation) }

    it "rejects an unknown role" do
      expect { Message.insert_all!([ { conversation_id: conversation.id, role: "system", content: "x" } ]) }
        .to raise_error(ActiveRecord::StatementInvalid, /messages_role_known/)
    end

    it "rejects an unknown status" do
      expect { Message.insert_all!([ { conversation_id: conversation.id, role: "user", status: "lost" } ]) }
        .to raise_error(ActiveRecord::StatementInvalid, /messages_status_known/)
    end

    it "rejects an unknown agent" do
      expect { Message.insert_all!([ { conversation_id: conversation.id, role: "assistant", agent: "chef" } ]) }
        .to raise_error(ActiveRecord::StatementInvalid, /messages_agent_known/)
    end
  end
end
