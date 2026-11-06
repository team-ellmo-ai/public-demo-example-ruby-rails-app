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

    def ellmo_piece(name)
      env = request.env
      lookup = env[Middleware::LOOKUP]
      return nil unless lookup

      (env[Middleware::RENDERED] ||= {})[name] = true
      value = lookup.value&.public_send(name)
      value.respond_to?(:html_safe) ? value.html_safe : value # rubocop:disable Rails/OutputSafety
    end
  end
end
