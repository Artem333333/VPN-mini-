
require_relative '../crypto/aead'

module HOVPN
  module Core
 
    class Session
      def initialize(key)
        @aead = HOVPN::Crypto::AEAD.new(key)
      end

      def decrypt_packet(data)
        return nil if data.size < 12 
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

      def add_session(client_id, key)
        @sessions[client_id] = Session.new(key)
        @logger.info("SessionManager: Сессия для #{client_id} создана.")
      end

    
      def find_session(ip, _port = nil)
        @sessions[ip]
      end
    end
  end
end