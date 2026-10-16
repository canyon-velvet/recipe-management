require "rails_helper"

RSpec.describe MealPlan do
  let(:user) { create(:user) }
  let(:monday) { Date.new(2026, 10, 12) }
  let(:plan) { user.meal_plans.create!(start_date: monday, end_date: monday + 6.days) }

  describe ".for_week_of" do
    it "finds the plan for the week a date falls in, Monday to Sunday" do
      plan

      expect(user.meal_plans.for_week_of(monday + 6.days)).to eq [ plan ]
      expect(user.meal_plans.for_week_of(monday + 7.days)).to be_empty
    end
  end

  describe "#recipes_for" do
    it "gives the recipes planned for one meal on a date" do
      dinner = create(:recipe, user: user)
      plan.meal_slots.find_by!(day_of_week: "friday", meal_type: "dinner").recipes << dinner

      expect(plan.recipes_for(monday + 4.days, :dinner)).to eq [ dinner ]
      expect(plan.recipes_for(monday + 4.days, :lunch)).to eq []
      expect(plan.recipes_for(monday + 3.days, :dinner)).to eq []
    end

    it "gives none for a date outside the plan's week" do
      plan.meal_slots.find_by!(day_of_week: "sunday", meal_type: "dinner").recipes << create(:recipe, user: user)

      expect(plan.recipes_for(monday - 1.day, :dinner)).to eq []
      expect(plan.recipes_for(monday + 13.days, :dinner)).to eq []
    end
  end
end
