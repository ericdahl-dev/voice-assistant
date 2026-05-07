Rails.application.routes.draw do
  devise_for :users

  mount GoodJob::Engine => "/good_job"

  get "up" => "rails/health#show", as: :rails_health_check

  # Delegations represent a user asking the AI to make a call on their behalf.
  # The nested call_plans resource handles CallPlan creation within a delegation.
  resources :delegations, only: [ :index, :show, :new, :create ] do
    resource :call_plan, only: [ :new, :create, :show, :edit, :update ] do
      post :approve, on: :member
    end
  end

  post "webhooks/vapi", to: "webhooks#vapi"
  resources :call_sessions, only: [ :show ]
  resources :escalations, only: [] do
    post :reply, on: :member
  end

  root to: "home#index"
end
