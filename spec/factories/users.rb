FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "cook#{n}" }
    password { "password" }

    trait :admin do
      admin { true }
    end
  end
end
