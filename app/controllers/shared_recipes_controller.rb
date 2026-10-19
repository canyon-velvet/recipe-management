# A shared recipe, read-only, for anyone with its link: no account needed, in any browser, and kept out of search
# engines.
class SharedRecipesController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @recipe = Recipe.includes(:source, :tags, :steps, recipe_ingredients: :ingredient)
                    .find_by!(share_token: params[:token].to_s)
  end

  private

  def open_to_any_browser? = true
end
