require 'securerandom'
require 'concurrent-ruby'
require 'json'
require_relative '../crypto/aead'
require_relative '../crypto/nonce'
require_relative '../crypto/replay_window'

module HOVPN
  module Core
    class Session
      attr_reader :session_id, :peer_id, :created_at, :stats, :state_history, :last_activity
      attr_accessor :endpoint, :last_handshake_at


      REKEY_AFTER_BYTES     = 1024**3 
      REKEY_AFTER_TIME      = 3600    
      REJECT_AFTER_TIME     = 86400   
      MAX_QUEUED_PACKETS    = 1024

      def initialize(peer_id, endpoint, shared_key)
        @session_id = SecureRandom.hex(16)
        @peer_id    = peer_id
        @endpoint   = endpoint
        @created_at = Time.now
        @last_handshake_at = Time.now
        @last_activity = Time.now


        @aead = HOVPN::Crypto::AEAD.new(shared_key)
        @tx_nonce_gen = HOVPN::Crypto::Nonce.new
        @rx_window = HOVPN::Crypto::ReplayWindow.new

     
        @stats = Concurrent::Hash.new({
          tx_bytes: 0, rx_bytes: 0,
          tx_packets: 0, rx_packets: 0,
          dropped_packets: 0,
          rtt_ms: 0.0
        })

        @outbound_queue = SizedQueue.new(MAX_QUEUED_PACKETS)
        @lock = Mutex.new
        @state_history = []
        
        record_event("Session initialized for peer #{peer_id} at #{endpoint[:ip]}")
      end

    

      def encrypt(plaintext)
        @lock.synchronize do
          nonce = @tx_nonce_gen.next!
          ciphertext = @aead.encrypt(nonce, plaintext)
          log_traffic(ciphertext.bytesize, :tx)
          [nonce, ciphertext]
        end
      rescue StandardError => e
        record_event("Encryption error: #{e.message}")
        nil
      end

      def decrypt(nonce_raw, ciphertext)
        @lock.synchronize do
         
          nonce_val = decode_nonce(nonce_raw)
          unless @rx_window.check?(nonce_val)
            @stats[:dropped_packets] += 1
            return nil
          end

    
          plaintext = @aead.decrypt(nonce_raw, ciphertext)
          
          if plaintext
            @rx_window.update!(nonce_val)
            log_traffic(ciphertext.bytesize, :rx)
            plaintext
          end
        end
      rescue StandardError => e
        @stats[:dropped_packets] += 1
        nil
      end

 

      def update_rtt!(measured_ms)
        @stats[:rtt_ms] = ((@stats[:rtt_ms] * 0.9) + (measured_ms * 0.1)).round(2)
      end

      def dead?
        Time.now - @last_activity > REJECT_AFTER_TIME
      end

      def should_rekey?
        time_limit = Time.now - @last_handshake_at > REKEY_AFTER_TIME
        data_limit = (@stats[:tx_bytes] + @stats[:rx_bytes]) > REKEY_AFTER_BYTES
        time_limit || data_limit
      end

      def to_h
        {
          session_id: @session_id,
          peer_id: @peer_id,
          endpoint: "#{@endpoint[:ip]}:#{@endpoint[:port]}",
          uptime: (Time.now - @created_at).to_i,
          stats: @stats.to_h,
          history: @state_history
        }
      end

      private

      def log_traffic(bytes, direction)
        @last_activity = Time.now
        @stats["#{direction}_bytes".to_sym] += bytes
        @stats["#{direction}_packets".to_sym] += 1
      end

      def decode_nonce(binary)
        low, high = binary.unpack('Q<L<')
        (high << 64) | low
      end

      def record_event(msg)
        @state_history << "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
        @state_history.shift if @state_history.size > 20
      end
    end
  end
end