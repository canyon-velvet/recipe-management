class MealPlan < ApplicationRecord
  DAYS_OF_WEEK = %w[monday tuesday wednesday thursday friday saturday sunday].freeze
  MEAL_TYPES = %w[breakfast lunch dinner snack].freeze

  belongs_to :user
  has_many :meal_slots, dependent: :destroy
  has_one :grocery_list, dependent: :destroy

  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :start_date, uniqueness: { scope: :user_id, message: :week_taken }
  validate :start_date_must_be_monday
  validate :end_date_must_be_sunday_after_start

  # The plan for the week a date falls in (weeks start on Monday)
  scope :for_week_of, ->(date) { where(start_date: date.beginning_of_week(:monday)) }

  after_create :create_meal_slots
  after_create :create_grocery_list

  def display_name
    name.presence || "#{start_date.strftime('%m/%d')} - #{end_date.strftime('%m/%d')}"
  end

  def assigned_recipe_count
    MealSlotRecipe.joins(:meal_slot).where(meal_slots: { meal_plan_id: id }).count
  end

  # The recipes planned for one meal on a date in this plan's week, e.g. today's dinner; none outside the week
  def recipes_for(date, meal_type)
    return [] unless date.between?(start_date, end_date)

    slot = meal_slots.find_by(day_of_week: DAYS_OF_WEEK[(date - start_date).to_i], meal_type: meal_type)
    slot ? slot.recipes.to_a : []
  end

  private

  def start_date_must_be_monday
    return if start_date.blank?
    errors.add(:start_date, :not_monday) unless start_date.monday?
  end

  def end_date_must_be_sunday_after_start
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, :not_sunday_after_start) unless end_date == start_date + 6.days
  end

  def create_meal_slots
    DAYS_OF_WEEK.each_with_index do |_day, day_index|
      MEAL_TYPES.each_with_index do |_meal, meal_index|
        meal_slots.create!(day_of_week: day_index, meal_type: meal_index)
      end
    end
  end
end
