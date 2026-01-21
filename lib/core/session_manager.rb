
require_relative '../crypto/aead'
require_relative '../crypto/replay_window'

module HOVPN
  module Core
  
    class Session
      attr_reader :client_id, :created_at

      def initialize(client_id, key)
        @client_id = client_id
        @created_at = Time.now
     
        @aead = HOVPN::Crypto::AEAD.new(key)
        
       
        @replay_window = HOVPN::Crypto::ReplayWindow.new
      end

    
      def decrypt_packet(data)
       
        return nil if data.nil? || data.bytesize < 12

        
        nonce_bytes = data[0...12]
        
        
        nonce_int = nonce_bytes.unpack1('Q<')

        unless @replay_window.check?(nonce_int)
         
          return nil
        end

      
        ciphertext = data[12..-1]
        decrypted = @aead.decrypt(nonce_bytes, ciphertext)

        @replay_window.update!(nonce_int) if decrypted
        
        decrypted
      end

    
      def encrypt_packet(nonce, plaintext)
        @aead.encrypt(nonce, plaintext)
      end
    end

    class SessionManager
      def initialize(logger)
        @logger = logger
        @sessions = {} 
      end

      def add_session(client_id, key)
        @sessions[client_id] = Session.new(client_id, key)
        @logger.info("SessionManager: Сессия для #{client_id} успешно инициализирована.")
      end

    
      def find_session(ip, _port = nil)
        @sessions[ip]
      end

    
      def remove_session(client_id)
        @sessions.delete(client_id)
        @logger.info("SessionManager: Сессия для #{client_id} удалена.")
      end

      def active_sessions_count
        @sessions.size
      end
    end
  end
end