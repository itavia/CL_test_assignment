Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :routes, only: [] do
        get "search", on: :collection
      end
    end
  end
end
