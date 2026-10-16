class GroceryList < ApplicationRecord
  belongs_to :meal_plan
  has_many :grocery_list_items, dependent: :destroy

  def user
    meal_plan.user
  end

  # Items still to buy: those not already in the pantry
  def to_buy_count = grocery_list_items.active.count
end
