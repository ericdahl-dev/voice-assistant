Rails.application.routes.draw do
  devise_for :users

  authenticate :user, lambda(&:admin?) do
    mount GoodJob::Engine => "/good_job"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  # Delegations represent a user asking the AI to make a call on their behalf.
  # The nested call_plans resource handles CallPlan creation within a delegation.
  resources :delegations, only: [ :index, :show, :new, :create ] do
    resource :call_plan, only: [ :new, :create, :show, :edit, :update ] do
      post :approve, on: :member
      post :run_again, on: :member
    end
  end

  post "webhooks/vapi", to: "webhooks#vapi"
  resources :call_sessions, only: [ :show ] do
    post :retry, on: :member
  end
  resources :escalations, only: [] do
    post :reply, on: :member
  end

  root to: "home#index"
end
