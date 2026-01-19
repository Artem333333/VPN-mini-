# frozen_string_literal: true

require 'securerandom'
require 'concurrent-ruby'
require 'json'

module HOVPN
  
  module Core
    
    class Session
      attr_reader :session_id, :peer_id, :created_at, :stats, :state_history
      attr_accessor :rx_key, :tx_key, :endpoint, :last_handshake_at

      
      REKEY_AFTER_BYTES     = 1024**3 
      REKEY_AFTER_TIME      = 3600    
      REJECT_AFTER_TIME     = 86400   
      REPLAY_WINDOW_SIZE    = 128     
      MAX_QUEUED_PACKETS    = 1024    

      def initialize(peer_id, endpoint = nil)
        @session_id = SecureRandom.hex(16)
        @peer_id    = peer_id
        @endpoint   = endpoint
        @created_at = Time.now
        @last_handshake_at = Time.now
        
        
        @stats = Concurrent::Hash.new({
          tx_bytes: 0, rx_bytes: 0,
          tx_packets: 0, rx_packets: 0,
          dropped_packets: 0,
          rtt_ms: 0.0,
          last_activity: Time.now
        })

        
        @tx_nonce = Concurrent::AtomicFixnum.new(0)
        @rx_nonce_max = 0
        @rx_window = 0 
        
        
        @outbound_queue = SizedQueue.new(MAX_QUEUED_PACKETS)
        
        @lock = Mutex.new
        @state_history = []
        record_event("Session initialized for peer #{peer_id}")
      
      end

      

      def next_tx_nonce!
        @tx_nonce.increment
      
      end

      
      def validate_and_update_rx_nonce!(nonce)
        @lock.synchronize do
         
          if nonce <= @rx_nonce_max - REPLAY_WINDOW_SIZE
            @stats[:dropped_packets] += 1
            return false 
          
          end

          
          if nonce > @rx_nonce_max
            diff = nonce - @rx_nonce_max
            
            @rx_window = (diff >= REPLAY_WINDOW_SIZE) ? 1 : (@rx_window << diff) | 1
            @rx_nonce_max = nonce
            return true
          
          end

          
          bit = @rx_nonce_max - nonce
          if (@rx_window & (1 << bit)) != 0
            @stats[:dropped_packets] += 1
            return false 
          
          end

         
          @rx_window |= (1 << bit)
          true
        
        end
      
      end

      
      def destroy_keys!
        @lock.synchronize do
          [@rx_key, @tx_key].each do |key|
            key.replace("\x00" * key.length) if key.respond_to?(:replace)
          end
          @rx_key = @tx_key = nil
          record_event("Security context cleared: Keys zeroed")
        
        end
      
      end

      

      def update_rtt!(measured_ms)
        
        @stats[:rtt_ms] = ((@stats[:rtt_ms] * 0.9) + (measured_ms * 0.1)).round(2)
      
      end

      def log_traffic(bytes, direction)
        @stats[:last_activity] = Time.now
        dir = direction == :tx ? :tx : :rx
        @stats["#{dir}_bytes".to_sym] += bytes
        @stats["#{dir}_packets".to_sym] += 1
      
      end

      

      def dead?
        Time.now - @stats[:last_activity] > REJECT_AFTER_TIME
      
      end

      def should_rekey?
        return false unless established?
        time_limit = Time.now - @last_handshake_at > REKEY_AFTER_TIME
        data_limit = (@stats[:tx_bytes] + @stats[:rx_bytes]) > REKEY_AFTER_BYTES
        time_limit || data_limit
      
      end

      def established?
        !@rx_key.nil? && !@tx_key.nil?
      
      end


      def to_h
        {
          session_id: @session_id,
          peer_id: @peer_id,
          endpoint: @endpoint,
          established: established?,
          uptime: (Time.now - @created_at).to_i,
          stats: @stats.to_h,
          history: @state_history
        }
      
      end

      def to_json(*_args); to_h.to_json; end

      private

      def record_event(msg)
        @state_history << "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
        @state_history.shift if @state_history.size > 20
      
      end
    
    end
  
  end

end