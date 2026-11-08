# frozen_string_literal: true

module EllmoAi
  # Rails integration: the middleware and the view helpers.
  class Railtie < Rails::Railtie
    # Innermost (just above the router), so Rack::ETag, ConditionalGet and any compression
    # middleware see the page with eLLMo content already in it.
    initializer "ellmo_ai.middleware" do |app|
      app.config.middleware.use EllmoAi::Middleware
      # Outermost, so page views carry the status the visitor got (see FinalStatus).
      app.config.middleware.insert_before 0, EllmoAi::FinalStatus
    end

    initializer "ellmo_ai.helpers" do
      ActiveSupport.on_load(:action_view) { include EllmoAi::Helpers }
    end
  end
end
