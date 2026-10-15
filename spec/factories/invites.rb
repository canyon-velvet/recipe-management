FactoryBot.define do
  factory :invite do
    created_by { association :user, :admin }
  end
end
