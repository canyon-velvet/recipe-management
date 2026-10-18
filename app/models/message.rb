# One message in a conversation: what the user asked, or the assistant's reply.
class Message < ApplicationRecord
  # Long enough for a recipe pasted in to import; the assistant only needs the last few messages' worth.
  MAX_LENGTH = 4_000
  # How many messages a user can send the assistant in any 24 hours. Each costs a Claude call.
  DAILY_LIMIT = 50

  belongs_to :conversation
  has_one :run, dependent: :destroy

  enum :role, { user: "user", assistant: "assistant" }, validate: true
  enum :status, { pending: "pending", done: "done", failed: "failed" }, validate: true
  # Who wrote a reply: the router, or the specialist it handed the message to.
  enum :agent, { router: "router", recommend: "recommend", import: "import" }, validate: { allow_nil: true }

  validates :content, presence: true, length: { maximum: MAX_LENGTH }, if: :user?

  attr_writer :recipes, :drafts

  # Loads the recipe and draft cards of many messages at once (the panel shows up to 50), instead of a few queries
  # each.
  def self.load_cards(messages, user)
    recipes = user.recipes.for_cards.where(id: messages.flat_map(&:recipe_ids)).index_by(&:id)
    drafts = user.drafts.where(id: messages.flat_map(&:draft_ids)).index_by(&:id)
    messages.each do |message|
      message.recipes = recipes.values_at(*message.recipe_ids).compact
      message.drafts = drafts.values_at(*message.draft_ids).compact
    end
  end

  # Sets the reply's recipe cards from { recipe id => why it fits }, in order.
  def cards=(cards)
    self.recipe_ids = cards.keys
    self.card_reasons = cards.transform_keys(&:to_s)
  end

  # Why the assistant recommends the recipe, shown on its card. Nil for older replies.
  def card_reason(recipe) = card_reasons[recipe.id.to_s]

  # Records the user's answer to a suggested preference: "saved" or "dismissed".
  # Only a pending suggestion can be decided, once. Locked, so two clicks at once (on one card or two) don't overwrite
  # each other's answer. Returns whether it was decided now.
  def decide_suggestion!(index, state)
    with_lock do
      suggestions = preference_suggestions.deep_dup
      next false unless suggestions.fetch(index)["state"] == "pending"

      suggestions[index]["state"] = state
      update!(preference_suggestions: suggestions)
      true
    end
  end

  # For a reply: the user's message it answers, the one asked just before it.
  def question = conversation.messages.user.where(id: ...id).last

  # The recipes shown as cards under a reply, in the order shown. Ones deleted since are left out.
  def recipes
    return @recipes if @recipes
    return [] if recipe_ids.empty?

    conversation.user.recipes.for_cards.where(id: recipe_ids).sort_by { |recipe| recipe_ids.index(recipe.id) }
  end

  # The drafts a reply imported, shown as cards that follow each import. Ones saved or discarded since are left out.
  def drafts
    return @drafts if @drafts
    return [] if draft_ids.empty?

    conversation.user.drafts.where(id: draft_ids).sort_by { |draft| draft_ids.index(draft.id) }
  end

  # Replaces the message in the user's open panel (any page, any tab) with its current state, and what the assistant
  # is doing while it isn't writing, such as searching recipes.
  def broadcast_to_panel(activity: nil)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ conversation.user, :assistant ], target: self,
      partial: "assistant/messages/message", locals: { message: self, activity: activity }
    )
  end
end
