class MealPlansController < ApplicationController
  before_action :set_meal_plan, only: [ :show, :destroy ]
  before_action :set_week_choices, only: [ :new, :create ]

  def index
    meal_plans = current_user.meal_plans.with_counts.order(start_date: :desc)
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

  # The first week offered that isn't planned yet, from next week (this week too on a Monday); none if all are
  def new
    earliest = Date.current.monday? ? Date.current : Date.current.next_week(:monday)
    start_date = (@mondays - @planned_mondays).find { |monday| monday >= earliest }
    @meal_plan = MealPlan.new(start_date: start_date)
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

  def set_week_choices
    @mondays = MealPlan.upcoming_mondays
    @planned_mondays = current_user.meal_plans.where(start_date: @mondays).pluck(:start_date)
  end

  def meal_plan_params
    params.require(:meal_plan).permit(:name, :start_date)
  end
end
