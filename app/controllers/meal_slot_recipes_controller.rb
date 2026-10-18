class MealSlotRecipesController < ApplicationController
  before_action :set_meal_slot, only: [ :create ]
  before_action :set_meal_slot_recipe, only: [ :destroy, :update ]

  def create
    meal_plan = @meal_slot.meal_plan
    recipe = current_user.recipes.find(params.dig(:meal_slot_recipe, :recipe_id))
    # Ticked for the grocery list if the recipe is ticked elsewhere in the week, as every copy of it is
    ticked = MealSlotRecipe.in_meal_plan(meal_plan).where(recipe: recipe).pick(:add_to_grocery_list) || false
    @meal_slot_recipe = @meal_slot.meal_slot_recipes.build(recipe: recipe, add_to_grocery_list: ticked)

    if @meal_slot_recipe.save
      SyncGroceryListService.new(meal_plan).call
      render_meal_slots(meal_plan, @meal_slot.id)
    else
      head :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique # the same recipe added twice at once (a double click)
    head :unprocessable_entity
  end

  def destroy
    meal_slot = @meal_slot_recipe.meal_slot
    @meal_slot_recipe.destroy
    SyncGroceryListService.new(meal_slot.meal_plan).call
    render_meal_slots(meal_slot.meal_plan, meal_slot.id)
  end

  def update
    @meal_slot_recipe.update(add_to_grocery_list: params.dig(:meal_slot_recipe, :add_to_grocery_list))
    meal_plan = @meal_slot_recipe.meal_slot.meal_plan

    # Find all meal_slot_recipes with the same recipe in this meal plan and sync them
    linked = MealSlotRecipe.in_meal_plan(meal_plan).where(recipe_id: @meal_slot_recipe.recipe_id)

    linked.update_all(add_to_grocery_list: @meal_slot_recipe.add_to_grocery_list)
    SyncGroceryListService.new(meal_plan).call

    render_meal_slots(meal_plan, linked.pluck(:meal_slot_id).uniq)
  end

  private

  # Redraws the changed meals, and the page's header for its counts of recipes planned and items to buy
  def render_meal_slots(meal_plan, slot_ids)
    slots = MealSlot.includes(meal_slot_recipes: { recipe: :tags }).where(id: slot_ids)
    streams = slots.map do |slot|
      turbo_stream.update("meal_slot_#{slot.id}", partial: "meal_plans/meal_slot_cell", locals: { meal_slot: slot })
    end
    streams << turbo_stream.update("meal_plan_header", partial: "meal_plans/header", locals: { meal_plan: meal_plan })

    respond_to do |format|
      format.turbo_stream { render turbo_stream: streams }
    end
  end

  def set_meal_slot
    @meal_slot = current_user.meal_slots.find(params[:meal_slot_id])
  end

  def set_meal_slot_recipe
    @meal_slot_recipe = current_user.meal_slot_recipes.includes(meal_slot: :meal_plan).find(params[:id])
  end
end
