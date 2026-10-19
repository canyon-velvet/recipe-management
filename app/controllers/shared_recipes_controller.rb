# A shared recipe, read-only, for anyone with its link: no account needed, and kept out of search engines.
class SharedRecipesController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @recipe = Recipe.includes(:source, :tags, :steps, recipe_ingredients: :ingredient)
                    .find_by!(share_token: params[:token].to_s)
  end
end
