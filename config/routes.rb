require "sidekiq/web"

Rails.application.routes.draw do
  # Authentication
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  get "register", to: "registrations#new"
  post "register", to: "registrations#create"
  resources :invites, only: [ :index, :create, :destroy ]

  # Language switcher
  resource :locale, only: [ :update ]

  # Recipes
  resources :recipes do
    get :search, on: :collection
  end
  # The Preview tab of a markdown field, rendered as it will be shown
  resource :markdown_preview, only: [ :create ]

  # Ingredients & Sources (AJAX search + inline create)
  resources :ingredients, only: [ :create ] do
    get :search, on: :collection
  end
  resources :aisles, only: [ :index, :create, :update, :destroy ] do
    patch :move, on: :member
  end
  resources :sources, only: [ :create ] do
    get :search, on: :collection
  end

  # Draft box: imported recipes waiting to be reviewed
  resources :imports, only: [ :new, :create ]
  resources :drafts, only: [ :index, :destroy ]

  # What the user eats, for the assistant's recommendations
  resources :preferences, only: [ :index, :create, :destroy ]

  # The assistant side panel
  namespace :assistant do
    resources :conversations, only: [ :create ]
    resources :messages, only: [ :create ] do
      # A reply's suggested preferences, by their position in it: Save or Skip
      resources :suggestions, only: [] do
        member do
          post :save
          post :dismiss
        end
      end
    end
  end

  # Meal Plans
  resources :meal_plans, only: [ :index, :show, :new, :create, :destroy ] do
    resource :grocery_list, only: [ :show ]
  end

  # Grocery List Items (pantry toggle)
  resources :grocery_list_items, only: [ :update ]

  # Meal Slot Recipes (add/remove recipes from slots)
  resources :meal_slots, only: [] do
    resources :meal_slot_recipes, only: [ :create ]
  end
  resources :meal_slot_recipes, only: [ :destroy, :update ]

  # Sidekiq dashboard: queued, running, retrying and failed jobs. Admins only; anyone else gets a 404.
  constraints ->(request) { User.find_by(id: request.session[:user_id])&.admin? } do
    mount Sidekiq::Web => "/sidekiq", as: :sidekiq
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  root "recipes#index"
end
