class GroceryList < ApplicationRecord
  belongs_to :meal_plan
  has_many :grocery_list_items, dependent: :destroy

  def user
    meal_plan.user
  end

  # Items still to buy: those not already in the pantry
  def to_buy_count = grocery_list_items.active.count

  # Items still to buy, grouped by aisle, in shopping order
  def active_groups = grocery_list_items.in_aisle_order.active.group_by { |item| item.ingredient.aisle }

  def pantry_items = grocery_list_items.in_aisle_order.in_pantry
end
