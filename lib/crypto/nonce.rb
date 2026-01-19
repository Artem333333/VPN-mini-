
require 'rbnacl'

module HOVPN
  module Crypto


    class Nonce
     5
      SIZE = 12
      
      MAX_VALUE = (1 << 96) - 1
   
      REKEY_THRESHOLD = 1_000_000

      attr_reader :current_value

      def initialize(start_value = 0)
        @current_value = start_value.to_i
        @lock = Mutex.new
      end

      
      def next!
        @lock.synchronize do
          
          if exhausted?
            raise HOVPN::Core::Errors::CryptoError, "Nonce sequence exhausted! Manual rekey required."
          end

         
          binary = [
            @current_value & 0xFFFFFFFFFFFFFFFF,
            (@current_value >> 64) & 0xFFFFFFFF
          ].pack('Q<L<')

          @current_value += 1
          binary
        end
      end

      
      def jump_to!(value)
        @lock.synchronize do
          raise "Cannot move nonce backwards!" if value < @current_value
          @current_value = value
        end
      end

      def exhausted?
        @current_value >= (MAX_VALUE - REKEY_THRESHOLD)
      end
     
      def self.random
        RbNaCl::Random.random_bytes(SIZE)
      end

     
      def reset!
        @lock.synchronize { @current_value = 0 }
      end

      
      def to_s
        "Nonce(val: #{@current_value}, usage: #{((@current_value.to_f / MAX_VALUE) * 100).round(8)}%)"
      end
    end
  end
end