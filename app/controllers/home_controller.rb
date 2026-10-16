# The home page: the way in to the recipes, imports and the assistant, with this week's plan and the latest recipes.
class HomeController < ApplicationController
  def show
    @recipe_count = current_user.recipes.count
    @recent_recipes = current_user.recipes.includes(:source, :tags).order(updated_at: :desc).limit(4)
    @meal_plan = current_user.meal_plans.for_week_of(Date.current).first
  end
end
