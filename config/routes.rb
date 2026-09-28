Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "webhooks/delivery", to: "webhooks/deliveries#create", as: :delivery_webhook

  root "cases#index"
  resources :cases, only: [ :index, :show ] do
    resources :actions, only: :create, controller: "case_actions"
  end
end
