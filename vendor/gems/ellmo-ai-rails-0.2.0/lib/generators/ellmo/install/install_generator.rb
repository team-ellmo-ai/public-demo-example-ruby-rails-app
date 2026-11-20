# frozen_string_literal: true

require "rails/generators"

module Ellmo
  module Generators
    # bin/rails g ellmo:install [CLIENT_ID]
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Creates config/initializers/ellmo.rb. Pass your eLLMo client ID, or set ELLMO_CLIENT_ID."

      argument :client_id, type: :string, required: false, default: nil, banner: "CLIENT_ID"

      def create_initializer
        template "ellmo.rb.tt", "config/initializers/ellmo.rb"
      end

      def show_next_steps
        say "\neLLMo AI is installed. Pages now get eLLMo content and page views are reported."
        say "Set ELLMO_CLIENT_ID in production if you didn't pass a client ID." unless client_id
        say "Optional: put <%= ellmo_structured %> in <head> and <%= ellmo_semantic %> in <body> to choose where content goes."
      end
    end
  end
end
