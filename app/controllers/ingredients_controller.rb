class IngredientsController < ApplicationController
  include PickerJson

  def search
    render_names current_user.ingredients.search_by_name(params[:q])
  end

  def create
    render_created current_user.ingredients.create(ingredient_params)
  end

  private

  def ingredient_params
    params.require(:ingredient).permit(:name, :aisle_id)
  end
end
