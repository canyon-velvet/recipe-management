class User < ApplicationRecord
  has_secure_password

  has_many :recipes, dependent: :destroy
  has_many :meal_plans, dependent: :destroy
  has_many :meal_slots, through: :meal_plans
  has_many :meal_slot_recipes, through: :meal_slots
  has_many :grocery_lists, through: :meal_plans
  has_many :grocery_list_items, through: :grocery_lists
  has_many :sources, dependent: :destroy
  has_many :ingredients, dependent: :destroy
  has_many :aisles, dependent: :destroy
  has_many :drafts, dependent: :destroy
  has_many :preferences, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :conversation_messages, through: :conversations, source: :messages

  validates :username, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { minimum: 2, maximum: 50 }
  validates :password, length: { minimum: 6 }, on: :create
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }

  normalizes :username, with: ->(username) { username.strip }

  # Every user shops with the default aisles until they change them.
  after_create { Aisle.create_defaults_for(self) }

  def admin?
    admin
  end

  # The conversation the assistant panel shows: the newest one (nil until the first message).
  def current_conversation = conversations.newest_first.first

  # Where the next message goes: the current conversation, started on the first message.
  def current_conversation! = current_conversation || conversations.create!

  # The user's "avoid" preferences, e.g. ["peanut", "花生"]. Recipes with them are flagged, not hidden.
  def avoided_ingredients = preferences.avoid.pluck(:value)

  # Whether the user has sent the assistant Message::DAILY_LIMIT messages in the last 24 hours. A rolling window, not
  # "today": the user picks their own time zone, and switching to one where the day has just begun mustn't reset it.
  def assistant_limit_reached?
    conversation_messages.where(role: :user, created_at: 24.hours.ago..).count >= Message::DAILY_LIMIT
  end

  # "New chat": a fresh conversation, unless the current one is still empty.
  def start_conversation
    current = current_conversation
    current && current.messages.none? ? current : conversations.create!
  end
end
