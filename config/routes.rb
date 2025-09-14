Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :segments, only: [:create]
      resources :permitted_routes, only: [:create]
      resources :routes, only: [:index]
    end
  end
end