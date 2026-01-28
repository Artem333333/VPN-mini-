lib_path = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib_path)

require 'core'

begin
  app = HomeNexus::App.new
  app.run
rescue Interrupt
  puts "\n[!] Выключение сервера..."
  exit
rescue LoadError => e
  puts "[ОШИБКА ЗАГРУЗКИ] Не найден файл: #{e.message}"

rescue => e
  puts "[ОШИБКА] #{e.message}"
end