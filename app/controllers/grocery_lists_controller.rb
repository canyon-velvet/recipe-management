class GroceryListsController < ApplicationController
  def show
    @meal_plan = current_user.meal_plans.find(params[:meal_plan_id])
    @grocery_list = @meal_plan.grocery_list
  end
end
