Rails.application.routes.draw do
  # Authentication routes
  get "/signup", to: "users#new"
  post "/signup", to: "users#create"
  get "/users/search", to: "users#search"
  get "/signin", to: "sessions#new"
  post "/signin", to: "sessions#create"
  delete "/signout", to: "sessions#destroy"

  # Two-factor authentication
  resource :two_factor_session, only: [:new, :create], path: "signin/2fa"
  resource :two_factor_settings, only: [:show, :new, :create, :destroy], path: "settings/2fa" do
    post :regenerate_backup_codes, on: :member
  end

  # Password reset
  resources :password_resets, only: [:edit, :update], param: :token
  
  # Dashboard routes
  get "/dashboard", to: "dashboard#index"
  
  # Channel routes
  resources :channels do
    member do
      get :join
      post :join
      delete :leave
      post :invite
    end
    resources :messages, only: [:create]
    resources :channel_memberships, only: [:index]
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

  # Documentation
  get "/docs", to: "docs#index"

  resource :settings, only: [:edit, :update] do
    get :mobile_setup, on: :member
  end
  namespace :admin do
    get '/', to: 'dashboard#index', as: :dashboard
    get '/credentials', to: 'dashboard#admin_credentials', as: :credentials
    resource :settings, only: [:edit, :update]
    resources :users, only: [:index, :update] do
      member do
        post :approve
        delete :reject
        post :generate_reset_link
      end
    end
    # Legacy redirect for old integrations path
    get '/integrations', to: redirect('/admin/settings/edit')
    # Keep test_connection endpoint for API testing
    get '/integrations/test_connection', to: 'integrations#test_connection', as: :integrations_test_connection
    resources :bots, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
      member do
        post :activate
        post :deactivate
        post :regenerate_secret
      end
    end
    resources :tokens, only: [:index, :create, :edit, :update, :destroy] do
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

      # Server info endpoint for discovery
      get :server_info, to: 'server_info#show'

      # Metrics endpoints
      get 'metrics/health', to: 'metrics#health'
      get :metrics, to: 'metrics#index'

      # Authentication endpoints
      post :signin, to: 'auth#signin'
      post 'signin/verify_2fa', to: 'auth#verify_2fa'
      post :signup, to: 'auth#signup'
      delete :signout, to: 'auth#signout'

      # User profile endpoints
      get :me, to: 'users#me'
      patch :me, to: 'users#update'
      post 'me/change_password', to: 'users#change_password'
      delete 'me/avatar', to: 'users#remove_avatar'

      # Two-factor authentication endpoints
      get '2fa/status', to: 'two_factor#status'
      post '2fa/setup', to: 'two_factor#setup'
      post '2fa/verify', to: 'two_factor#verify'
      post '2fa/disable', to: 'two_factor#disable'
      get '2fa/backup_codes', to: 'two_factor#backup_codes'
      post '2fa/regenerate_backup_codes', to: 'two_factor#regenerate_backup_codes'

      # FCM token endpoint
      put :fcm_token, to: 'fcm#update_token'
      
      # Message endpoints
      post :messages, to: 'messages#create'
      get :messages, to: 'messages#index'
      delete 'messages/:id', to: 'messages#destroy', as: :delete_message
      # Search endpoint
      get :search, to: 'search#index'
      get 'users/search', to: 'search#search_users'

      # Channel-scoped API
      resources :channels, only: [:index, :create] do
        member do
          post :messages, to: 'messages#create_for_channel'
          post :media, to: 'messages#create_media'
          post :join
          delete :leave
          get :members
          post :mark_as_read
        end
      end
      # DM endpoints
      get 'dm/channels', to: 'messages#dm_channels'
      post 'users/:id/messages', to: 'messages#create_dm', as: :user_messages
      post 'dm/start', to: 'messages#start_dm_by_username'
      
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

  # ActionCable WebSocket endpoint
  mount ActionCable.server => '/cable'
end
