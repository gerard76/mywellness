Rails.application.routes.draw do
  root "home#index"

  resources :machines, only: [:index, :update]
  resources :uploads,  only: [:new, :create]

  resource :settings, only: [:show, :update]

  resource :sync, only: [:create], controller: "sync"

  get "up" => "rails/health#show", as: :rails_health_check
end
