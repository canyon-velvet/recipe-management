class MealPlansController < ApplicationController
  before_action :set_meal_plan, only: [ :show, :destroy ]

  def index
    meal_plans = current_user.meal_plans.order(start_date: :desc)
    @pagy, @meal_plans = pagy(meal_plans)
  end

  def show
    slots = @meal_plan.meal_slots.includes(meal_slot_recipes: { recipe: :tags })
    @grid = {}
    day_map = MealPlan::DAYS_OF_WEEK.each_with_index.to_h
    meal_map = MealPlan::MEAL_TYPES.each_with_index.to_h
    slots.each do |slot|
      day = day_map[slot.day_of_week]
      meal = meal_map[slot.meal_type]
      @grid[day] ||= {}
      @grid[day][meal] = slot
    end
  end

  def new
    @meal_plan = MealPlan.new
    @meal_plan.start_date = Date.current.beginning_of_week(:monday)
    @meal_plan.start_date += 7.days unless @meal_plan.start_date == Date.current
  end

  def create
    @meal_plan = current_user.meal_plans.build(meal_plan_params)
    @meal_plan.end_date = @meal_plan.start_date + 6.days if @meal_plan.start_date.present?

    if @meal_plan.save
      redirect_to meal_plan_path(@meal_plan), notice: t("flash.meal_plan_created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @meal_plan.destroy
    redirect_to meal_plans_path, notice: t("flash.meal_plan_deleted")
  end

  private

  def set_meal_plan
    @meal_plan = current_user.meal_plans.find(params[:id])
  end

  def meal_plan_params
    params.require(:meal_plan).permit(:name, :start_date)
  end
end
