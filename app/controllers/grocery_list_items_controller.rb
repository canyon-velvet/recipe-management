class GroceryListItemsController < ApplicationController
  before_action :set_item

  def update
    @item.update!(in_pantry: params[:in_pantry])

    # The whole list is drawn again, so the item lands in its aisle or in Already have, and the counts follow
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("grocery_list", partial: "grocery_lists/list",
                                                                 locals: { grocery_list: @item.grocery_list })
      end
    end
  end

  private

  def set_item
    @item = GroceryListItem.includes(ingredient: :aisle, grocery_list: :meal_plan).find(params[:id])
    meal_plan = @item.grocery_list.meal_plan
    redirect_to meal_plans_path, alert: t("flash.not_authorized") unless meal_plan.user_id == current_user.id
  end
end
