require 'singleton'
require 'async'
require_relative 'errors'
require_relative 'logger'
require_relative 'state_machine'
require_relative 'session_manager'

# Подключаем сетевой стек
require_relative '../network/udp_stack'

module HOVPN
  module Core
    class Application
      include Singleton

      def initialize
        @running = false
      end

      def bootstrap!(_config_path)
        @logger = HOVPN::Core::Logger.new
        @logger.info('HOVPN: Bootstrapping components...')

        @state_machine   = HOVPN::Core::StateMachine.new(@logger)
        @session_manager = HOVPN::Core::SessionManager.new(@logger)
        @udp_stack       = HOVPN::Network::UDPStack.new(@logger)

        # Добавляем тестовую сессию для нашего клиента
        # Ключ должен быть ровно 32 байта
        test_key = "12345678901234567890123456789012".dup.force_encoding("BINARY")
        @session_manager.add_session("127.0.0.1", test_key)

        @logger.info('HOVPN: Bootstrap complete. Test session loaded.')
      end

      def run!
        @running = true
        Async do |task|
          @udp_stack.bind!
          @logger.info('HOVPN: Engine is humming...')

          # Запуск прослушивания сети
          task.async { @udp_stack.listen(@session_manager) }
        end
      end
    end
  end
end