Rails.application.routes.draw do
  devise_for :users

  mount GoodJob::Engine => "/good_job"

  get "up" => "rails/health#show", as: :rails_health_check

  root to: "home#index"
end
