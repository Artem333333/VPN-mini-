# frozen_string_literal: true

require_relative 'lib/hovpn'
require_relative 'lib/application'

puts "--- HOVPN: Home Office VPN Startup ---"

begin
  # В будущем здесь будет загрузка из config.yml
  app = HOVPN::Application.instance
  app.bootstrap!
  app.run!
rescue Interrupt
  puts "\nShutdown gracefully..."
  exit(0)
rescue StandardError => e
  puts "Fatal error on startup: #{e.message}"
  puts e.backtrace.join("\n")
end