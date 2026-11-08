# frozen_string_literal: true

# Runs FakeEllmo (test/support/fake_ellmo.rb) as a server, for scripts/try-ellmo.sh.
#   FAKE_ELLMO_PORT=4010 FAKE_ELLMO_VISITS=false ruby scripts/fake_ellmo_server.rb
require_relative "../test/support/fake_ellmo"

ellmo = FakeEllmo.new(port: Integer(ENV.fetch("FAKE_ELLMO_PORT", "4010")))
ellmo.access = { "visits" => ENV["FAKE_ELLMO_VISITS"] != "false", "content" => ENV["FAKE_ELLMO_CONTENT"] != "false" }
$stdout.sync = true
puts "fake eLLMo on #{ellmo.url} (#{ellmo.access})"
trap("TERM") { exit }
trap("INT") { exit }
sleep
