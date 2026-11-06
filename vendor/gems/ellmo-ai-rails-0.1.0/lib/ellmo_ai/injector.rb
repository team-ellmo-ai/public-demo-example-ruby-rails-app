# frozen_string_literal: true

module EllmoAi
  # Puts content into an HTML document, the same way the eLLMo edge workers do:
  # structured data at <!--ELLMO_JSONLD--> or else before </head>; semantic HTML at
  # <!--ELLMO_SUMMARY--> or else right after the opening <body> tag. A piece with no place
  # to go is left out; the page is never otherwise changed.
  module Injector
    JSONLD_MARKER = "<!--ELLMO_JSONLD-->"
    SUMMARY_MARKER = "<!--ELLMO_SUMMARY-->"
    HEAD_CLOSE = %r{</head\s*>}i
    BODY_OPEN = /<body\b[^>]*>/i

    module_function

    # Returns the new HTML, or nil when nothing was added.
    def inject(html, structured:, semantic:)
      html = utf8(html)
      return nil unless html

      changed = false
      if structured
        if html.include?(JSONLD_MARKER)
          html = html.sub(JSONLD_MARKER) { structured }
          changed = true
        elsif html.match?(HEAD_CLOSE)
          html = html.sub(HEAD_CLOSE) { |tag| "#{structured}#{tag}" }
          changed = true
        end
      end
      if semantic
        if html.include?(SUMMARY_MARKER)
          html = html.sub(SUMMARY_MARKER) { semantic }
          changed = true
        elsif html.match?(BODY_OPEN)
          html = html.sub(BODY_OPEN) { |tag| "#{tag}#{semantic}" }
          changed = true
        end
      end
      changed ? html : nil
    end

    # Response bodies are often binary strings; content is UTF-8. Skip anything that isn't UTF-8.
    def utf8(html)
      html = html.dup.force_encoding(Encoding::UTF_8) unless html.encoding == Encoding::UTF_8
      html.valid_encoding? ? html : nil
    end
  end
end
