# frozen_string_literal: true

require "cgi"

module EllmoAi
  # `config.hide_other_json_ld`: makes eLLMo's structured data the only active JSON-LD on the
  # page, for consumers that run JavaScript (Googlebot's renderer, browser-based AI agents).
  #
  # eLLMo's JSON-LD is tagged `data-ellmo-schema`, and a small inline script changes the `type`
  # of every other `application/ld+json` block to `application/ld+json+hidden`. The script does
  # nothing unless a tagged block is on the page, so a page without eLLMo content keeps its own
  # JSON-LD. Raw-HTML crawlers still see every block as sent.
  module JsonLdCleanup
    ATTRIBUTE = "data-ellmo-schema"

    # The opening tag of a JSON-LD <script> not tagged yet: "<script" + its attributes, then ">".
    LD_OPEN = %r{<script\b(?=[^>]*\btype\s*=\s*["']?application/ld\+json["'\s>])(?![^>]*\bdata-ellmo-schema\b)([^>]*)>}i

    # Once the DOM is ready, and again after every Turbo visit (`turbo:load`): hide the other
    # JSON-LD if eLLMo's is on the page, else show what it hid. The Turbo listener is added once per
    # document. Byte-identical to the React SDK's inline script (CLEANUP_BODY).
    SCRIPT_BODY = "(function(){function h(){if(document.querySelector('script[data-ellmo-schema]')){" \
                  "document.querySelectorAll('script[type=\"application/ld+json\"]:not([data-ellmo-schema])')" \
                  ".forEach(function(s){s.type='application/ld+json+hidden';s.setAttribute('data-ellmo-hidden','');});}" \
                  "else{document.querySelectorAll('script[data-ellmo-hidden]')" \
                  ".forEach(function(s){s.type='application/ld+json';s.removeAttribute('data-ellmo-hidden');});}}" \
                  "if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',h);}else{h();}" \
                  "if(!window.__ellmoJsonLd){window.__ellmoJsonLd=1;document.addEventListener('turbo:load',h);}})();"

    module_function

    # Adds data-ellmo-schema to every JSON-LD <script> in eLLMo's structured data. Tags that
    # already have it are left as they are.
    def tag(structured)
      structured&.gsub(LD_OPEN) { "<script#{Regexp.last_match(1)} #{ATTRIBUTE}>" }
    end

    # The cleanup <script>, with the page's CSP nonce when there is one.
    def script(nonce: nil)
      nonce_attr = nonce.to_s.empty? ? "" : %( nonce="#{CGI.escapeHTML(nonce.to_s)}")
      "<script data-ellmo-cleanup#{nonce_attr}>#{SCRIPT_BODY}</script>"
    end

    # What goes where eLLMo's structured data goes: as is when the setting is off; tagged and
    # followed by the cleanup script when it's on. Nothing when there is no structured data.
    def apply(structured, config, env)
      return structured if structured.nil? || structured.empty? || !config.hide_other_json_ld

      "#{tag(structured)}#{script(nonce: csp_nonce(env))}"
    end

    # The request's Content-Security-Policy nonce (Rails 5.2+, when the app configures a nonce
    # generator), so strict policies let the script run. nil elsewhere.
    def csp_nonce(env)
      return nil unless defined?(ActionDispatch::Request)

      request = ActionDispatch::Request.new(env)
      request.respond_to?(:content_security_policy_nonce) ? request.content_security_policy_nonce : nil
    rescue StandardError
      nil
    end
  end
end
