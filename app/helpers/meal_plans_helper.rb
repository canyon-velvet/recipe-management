module MealPlansHelper
  def day_label(index)
    t(MealPlan::DAYS_OF_WEEK[index], scope: "meal_plans.days")
  end

  def meal_type_label(index)
    t(MealPlan::MEAL_TYPES[index], scope: "meal_plans.meal_types")
  end

  # The plan's name, or its week when it has none
  def meal_plan_title(meal_plan) = meal_plan.name.presence || week_dates(meal_plan.start_date)

  # A week from its Monday, in the language in use: "Oct 12 – Oct 18" (10月12日 – 10月18日). year: true adds the year.
  def week_dates(monday, year: false)
    "#{l(monday, format: :month_day)} – #{l(monday + 6.days, format: year ? :month_day_year : :month_day)}"
  end
end
