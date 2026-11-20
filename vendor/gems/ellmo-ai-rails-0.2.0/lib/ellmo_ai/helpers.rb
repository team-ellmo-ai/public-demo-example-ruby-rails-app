# frozen_string_literal: true

module EllmoAi
  # View helpers for choosing where content goes. Each one returns the content (or nil) and
  # tells the middleware not to add that piece again.
  #
  #   <head> ... <%= ellmo_structured %> </head>
  #   <body> <%= ellmo_semantic %> ... </body>
  module Helpers
    def ellmo_structured
      ellmo_piece(:structured)
    end

    def ellmo_semantic
      ellmo_piece(:semantic)
    end

    private

    # Never breaks the view: outside a request (mailers) or on any error, it renders nothing.
    def ellmo_piece(name)
      env = respond_to?(:request) && request&.env
      lookup = env && env[Middleware::LOOKUP]
      return nil unless lookup

      (env[Middleware::RENDERED] ||= {})[name] = true
      value = lookup.value&.public_send(name)
      value = JsonLdCleanup.apply(value, EllmoAi.config, env) if name == :structured
      value.respond_to?(:html_safe) ? value.html_safe : value # rubocop:disable Rails/OutputSafety
    rescue StandardError => e
      EllmoAi.config.logger&.warn("[ellmo-ai] ellmo_#{name} skipped: #{e.class}: #{e.message}")
      nil
    end
  end
end
