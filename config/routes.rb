Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "webhooks/delivery", to: "webhooks/deliveries#create", as: :delivery_webhook
end
