require 'ruby_installer'

RubyInstaller::Runtime.add_dll_directory(File.expand_path(__dir__))

app_file = File.expand_path('lib/core/application.rb', __dir__)
if File.exist?(app_file)
  require_relative 'lib/core/application'
else
  puts "ERROR: File not found at #{app_file}"
  exit 1
end

begin
  app = HOVPN::Core::Application.instance
  app.bootstrap!('config.yaml')
  app.run!
rescue StandardError => e
  puts "ERROR: #{e.message}"
  puts e.backtrace.first(3)
end
