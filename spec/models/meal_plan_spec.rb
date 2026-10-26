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

  describe "#planned_meal_count" do
    it "counts the meals with a recipe, not the recipes" do
      dinner = plan.meal_slots.find_by!(day_of_week: "monday", meal_type: "dinner")
      dinner.recipes << create(:recipe, user: user) << create(:recipe, user: user)
      plan.meal_slots.find_by!(day_of_week: "tuesday", meal_type: "lunch").recipes << create(:recipe, user: user)

      expect(plan.planned_meal_count).to eq 2
    end
  end

  describe "#this_week? and #next_week?" do
    it "tell this week's and next week's plans from the others" do
      travel_to(monday + 6.days) do
        expect(plan).to be_this_week
        expect(plan).not_to be_next_week
      end
      travel_to(monday - 1.day) do
        expect(plan).not_to be_this_week
        expect(plan).to be_next_week
      end
    end
  end
end
