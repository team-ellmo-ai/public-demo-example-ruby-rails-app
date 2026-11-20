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
    # <body ...>, with quoted attribute values that may contain ">"
    BODY_OPEN = /<body\b(?:[^>"']|"[^"]*"|'[^']*')*>/i
    # Where </head> or <body> may appear without being the page's own: comments (including IE
    # conditional comments), scripts (document.write strings), styles and templates. Each runs to
    # its end, or to the end of the page when it's never closed.
    SKIPPED = %r{<!--.*?(?:-->|\z)|<script\b.*?(?:</script\s*>|\z)|<style\b.*?(?:</style\s*>|\z)|<template\b.*?(?:</template\s*>|\z)}mi

    module_function

    # Returns the new HTML, or nil when nothing was added.
    def inject(html, structured:, semantic:)
      html = utf8(html)
      return nil unless html
      return nil if other_charset?(html)

      changed = false
      if structured
        if html.include?(JSONLD_MARKER)
          html = html.sub(JSONLD_MARKER) { structured }
          changed = true
        elsif (at = find(html, HEAD_CLOSE))
          html = html.dup.insert(at.begin(0), structured)
          changed = true
        end
      end
      if semantic
        if html.include?(SUMMARY_MARKER)
          html = html.sub(SUMMARY_MARKER) { semantic }
          changed = true
        elsif (at = find(html, BODY_OPEN))
          html = html.dup.insert(at.end(0), semantic)
          changed = true
        end
      end
      changed ? html : nil
    end

    # A <meta charset> (or http-equiv Content-Type) for anything but UTF-8 near the top of the
    # page, where browsers look for it: eLLMo's UTF-8 content would show garbled there.
    META_CHARSET = /<meta\b[^>]*?charset\s*=\s*["']?([\w.:-]+)/i
    def other_charset?(html)
      charset = html[0, 2048][META_CHARSET, 1]
      !charset.nil? && !%w[utf-8 utf8].include?(charset.downcase)
    end

    # The first match of `target` outside comments, scripts, styles and templates, or nil.
    def find(html, target)
      scan = Regexp.union(SKIPPED, target)
      position = 0
      while (match = scan.match(html, position))
        return match if match[0].match?(/\A#{target.source}\z/i) && !match[0].match?(/\A#{SKIPPED.source}\z/mi)

        position = match.end(0)
      end
      nil
    end

    # Response bodies are often binary strings; content is UTF-8. Skip anything that isn't UTF-8.
    def utf8(html)
      html = html.dup.force_encoding(Encoding::UTF_8) unless html.encoding == Encoding::UTF_8
      html.valid_encoding? ? html : nil
    end
  end
end
