if Gem.win_platform?
  require 'ffi'
  SODIUM_PATH = 'C:/Ruby33-x64/msys64/mingw64/bin/libsodium-26.dll'
  
  # 1. Принудительно загружаем DLL в память через FFI
  module SodiumInternal
    extend FFI::Library
    ffi_lib SODIUM_PATH
  end
  puts "DEBUG: Sodium library pre-loaded into process memory."

  # 2. Магия: Взламываем метод ffi_lib в RbNaCl, чтобы он не искал файл
  # Мы переопределяем его так, чтобы он всегда возвращал нашу уже загруженную библиотеку
  require 'rbnacl'
  module RbNaCl
    module Sodium
      def self.extended(base)
        base.extend FFI::Library
        # Вместо поиска 'sodium' подставляем полный путь
        base.ffi_lib 'C:/Ruby33-x64/msys64/mingw64/bin/libsodium-26.dll'
      end
    end
  end
end

# Теперь подключаем всё остальное
require_relative 'lib/core/application'

begin
  puts "DEBUG: Starting HOVPN Engine..."
  app = HOVPN::Core::Application.instance
  app.bootstrap!('config.yaml')
  app.run!
rescue LoadError => e
  puts "Критическая ошибка загрузки: #{e.message}"
rescue StandardError => e
  puts "Ошибка при запуске: #{e.message}"
end