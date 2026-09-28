Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "webhooks/delivery", to: "webhooks/deliveries#create", as: :delivery_webhook

  root "cases#index"
  resources :cases, only: [ :index, :show ] do
    resources :actions, only: :create, controller: "case_actions"
  end

  get "demo", to: "demo#show", as: :demo
  post "demo/start", to: "demo#start", as: :demo_start
  post "demo/restart", to: "demo#restart", as: :demo_restart
  post "demo/simulate", to: "demo#simulate", as: :demo_simulate
  get "demo/step/:number", to: "demo#step", as: :demo_step
  get "demo/finish", to: "demo#finish", as: :demo_finish
  delete "demo", to: "demo#leave", as: :demo_leave
end
