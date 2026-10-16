module MealPlansHelper
  def day_label(index)
    t(MealPlan::DAYS_OF_WEEK[index], scope: "meal_plans.days")
  end

  def meal_type_label(index)
    t(MealPlan::MEAL_TYPES[index], scope: "meal_plans.meal_types")
  end

  def format_week_range(meal_plan)
    format_week_of(meal_plan.start_date)
  end

  def format_week_of(monday)
    "#{monday.strftime('%m/%d')} - #{(monday + 6.days).strftime('%m/%d')}"
  end
end
