# frozen_string_literal: true
require 'bundler/setup'
require 'fiddle'

# Блок загрузки DLL (УЖЕ РАБОТАЕТ У ТЕБЯ)
begin
  dll_path = File.expand_path("sodium.dll", __dir__)
  Fiddle.dlopen(dll_path)
  ENV['SODIUM_LIB'] = dll_path
  puts "✅ Библиотека загружена напрямую через Fiddle!"
rescue => e
  puts "❌ Ошибка загрузки DLL: #{e.message}"
  exit
end

require 'rbnacl'
puts "✅ Криптография (RbNaCl) готова к работе!"

# Настройка путей
$LOAD_PATH.unshift File.expand_path('lib', __dir__)

# ЗАГРУЗКА БЕЗ ОШИБКИ WRAPPER
require 'async'
begin
  require 'async/io'
rescue LoadError => e
  # Если это та самая ошибка async/wrapper, мы ее просто игнорируем
  raise e unless e.message.include?('async/wrapper')
end

require 'hovpn'
require 'application'

puts "--- HOVPN: Инициализация системы ---"

begin
  app = HOVPN::Application.instance
  app.bootstrap!
  app.run!
rescue Interrupt
  puts "\n[!] Выход..."
rescue StandardError => e
  puts "\n[!] ОШИБКА: #{e.message}"
  puts e.backtrace.first(5)
end