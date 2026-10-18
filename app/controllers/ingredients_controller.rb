class IngredientsController < ApplicationController
  def search
    ingredients = current_user.ingredients.search_by_name(params[:q]).order(:name).limit(20)
    render json: ingredients.map { |i| { id: i.id, name: i.name } }
  end

  def create
    ingredient = current_user.ingredients.new(ingredient_params)

    if ingredient.save
      render json: { id: ingredient.id, name: ingredient.name }, status: :created
    else
      render json: { errors: ingredient.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def ingredient_params
    params.require(:ingredient).permit(:name, :aisle_id)
  end
end
