
require_relative '../crypto/aead'
require_relative '../crypto/replay_window'

module HOVPN
  module Core

    class Session
      attr_reader :client_id, :created_at, :last_seen

      def initialize(client_id, recv_key, send_key)
        @client_id = client_id
        @created_at = Time.now
        @last_seen = Time.now

        
        @ingress_cipher = HOVPN::Crypto::AEAD.new(recv_key)
        @egress_cipher  = HOVPN::Crypto::AEAD.new(send_key)

        
        @replay_window = HOVPN::Crypto::ReplayWindow.new
      end

   
      def decrypt_packet(data)
        return nil if data.nil? || data.bytesize < 12

        nonce_bytes = data[0...12]
        nonce_int   = nonce_bytes.unpack1('Q<') 

        return nil unless @replay_window.check?(nonce_int)

        ciphertext = data[12..-1]
        decrypted = @ingress_cipher.decrypt(nonce_bytes, ciphertext)

        if decrypted
          @replay_window.update!(nonce_int)
          @last_seen = Time.now
        end

        decrypted
      end

      def encrypt_packet(nonce_bytes, plaintext)
        @egress_cipher.encrypt(nonce_bytes, plaintext)
      end
    end

    class SessionManager
      def initialize(logger)
        @logger = logger
        @sessions = {}
      end

      def establish_session(client_id, keys)
        session = Session.new(client_id, keys[:recv_key], keys[:send_key])
        
        @sessions[client_id] = session
        @logger.info("SessionManager: Защищенный туннель для #{client_id} установлен.")
        session
      end

      def find_session(ip, _port = nil)
        @sessions[ip]
      end

      def terminate_session(client_id)
        if @sessions.delete(client_id)
          @logger.info("SessionManager: Сессия #{client_id} закрыта.")
        end
      end

      def active_count
        @sessions.size
      end

      def session_exists?(ip)
        @sessions.key?(ip)
      end
    end
  end
end