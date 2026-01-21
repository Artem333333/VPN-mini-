# frozen_string_literal: true
require 'singleton'

module HOVPN
  class Application
    include Singleton

    def bootstrap!
      puts "[*] Проверка ключей..."
      HOVPN::Crypto::KeyPair.ensure_exists!(HOVPN.config['private_key_path'])
      
      puts "[*] Инициализация сетевого интерфейса..."
      @interface = HOVPN::Interface::TunAdapter.new
    end

    def run!
      Async do |task|
        puts "🚀 VPN ГОТОВ К РАБОТЕ!"
        @interface.start_capture(task)
      end
    end
  end
end