Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  Rails.application.routes.draw do
    resources :articles, only: [ :index, :show ] do
      collection do
        delete :reset_game # Using DELETE for a reset is standard REST
      end

      member do
        post :reveal # This allows us to save the "solved" state to the session
      end
    end

    root "articles#index"

    resources :trends, only: [ :index, :show ]
  end
end
