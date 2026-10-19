# The owner's side of a recipe's share link: make it, show it to send, and stop it.
class RecipeSharesController < ApplicationController
  before_action :set_recipe

  def show
    redirect_to recipe_path(@recipe) unless @recipe.share_token
  end

  def create
    @recipe.share!
    redirect_to recipe_share_path(@recipe)
  end

  def destroy
    @recipe.stop_sharing!
    # Back to the recipe page or the recipe list, wherever the pop-up was opened
    redirect_back_or_to recipe_path(@recipe), notice: t("flash.sharing_stopped")
  end

  private

  def set_recipe
    @recipe = current_user.recipes.find(params[:recipe_id])
  end
end
