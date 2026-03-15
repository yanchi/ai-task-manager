Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root "tasks#index", as: :authenticated_root
  end

  devise_scope :user do
    root to: "devise/sessions#new"
  end

  resources :tasks do
    member do
      patch :toggle
    end
    collection do
      post :ai_suggest
    end
  end

  # Reveal health status on /up that returns 200 if the app boots without exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
