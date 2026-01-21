# frozen_string_literal: true
require_relative '../crypto/aead'

module HOVPN
  module Core
    # Вспомогательный класс для сессии
    class Session
      def initialize(key)
        @aead = HOVPN::Crypto::AEAD.new(key)
      end

      def decrypt_packet(data)
        return nil if data.size < 12 # Минимум 12 байт для nonce
        nonce = data[0...12]
        ciphertext = data[12..-1]
        @aead.decrypt(nonce, ciphertext)
      end
    end

    class SessionManager
      def initialize(logger)
        @logger = logger
        @sessions = {}
      end

      # Принимает ID и Ключ, создает объект Session
      def add_session(client_id, key)
        @sessions[client_id] = Session.new(key)
        @logger.info("SessionManager: Сессия для #{client_id} создана.")
      end

      # Теперь принимает ip и port, как просит UDPStack
      def find_session(ip, _port = nil)
        @sessions[ip]
      end
    end
  end
end