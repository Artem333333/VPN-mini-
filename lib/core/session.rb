require_relative '../crypto/aead'

module HOVPN
  module Core
    class Session
      attr_reader :session_id, :endpoint

      def initialize(session_id, key, ip, port)
        @session_id = session_id
        @aead = HOVPN::Crypto::AEAD.new(key)
        @endpoint = { ip: ip, port: port }
        @last_seen = Time.now
      end

      def decrypt_packet(data)
        @last_seen = Time.now

        nonce = data[0...12]
        payload = data[12..-1]
        @aead.decrypt(nonce, payload)
      end

      def dead?
        Time.now - @last_seen > 300
      end
    end
  end
end
