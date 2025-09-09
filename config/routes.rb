Rails.application.routes.draw do
  # Authentication routes
  get "/signup", to: "users#new"
  post "/signup", to: "users#create"
  get "/signin", to: "sessions#new"
  post "/signin", to: "sessions#create"
  delete "/signout", to: "sessions#destroy"
  
  # Dashboard routes
  get "/dashboard", to: "dashboard#index"
  
  # Channel routes
  resources :channels do
    member do
      post :join
      delete :leave
      post :invite
    end
    resources :messages, only: [:create]
  end
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  # Static pages
  get "/privacy", to: "pages#privacy"
  get "/terms", to: "pages#terms"
  get "/about", to: "pages#about"

  resource :settings, only: [:edit, :update]
  namespace :admin do
    get '/', to: 'dashboard#index', as: :dashboard
    resource :settings, only: [:edit, :update]
    resources :users, only: [:index, :update]
    resources :integrations, only: [:index] do
      collection do
        post :create_token
        patch :update_settings
        get :test_connection
      end
      member do
        patch :regenerate_token
        patch :deactivate_token
        patch :activate_token
      end
    end
    resources :bots, only: [:index, :destroy] do
      member do
        post :activate
        post :deactivate
      end
    end
    resources :tokens, only: [:index, :create, :destroy] do
      member do
        post :activate
        post :deactivate
        post :regenerate
      end
    end
  end

  resources :dms, only: [:new, :create]
  # Quick-start a DM with a username
  get "/dm/:username", to: "dms#start", as: :start_dm

  # API routes for Home Assistant integration
  namespace :api do
    namespace :v1 do
      # Health check endpoint
      get :health, to: 'health#show'
      
      # Message endpoints
      post :messages, to: 'messages#create'
      get :messages, to: 'messages#index'
      # Channel-scoped API
      resources :channels, only: [:index] do
        member do
          post :messages, to: 'messages#create_for_channel'
          post :media, to: 'messages#create_media'
        end
      end
      # DM endpoint
      post 'users/:id/messages', to: 'messages#create_dm', as: :user_messages
      
      # Bot management endpoints
      resources :bots, only: [:create, :show, :index, :update, :destroy] do
        member do
          get :status
          post :activate
          post :deactivate
        end
      end
      
      # Webhook endpoints for bot communication
      post 'webhooks/:webhook_id', to: 'webhooks#receive', as: :webhook
    end
  end
end
