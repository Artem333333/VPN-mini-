
require 'rbnacl'
require_relative '../core/errors'

module HOVPN
  module Crypto
    class Nonce
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
          raise HOVPN::Core::Errors::CryptoError, "Nonce exhausted!" if exhausted?

          binary = [@current_value & 0xFFFFFFFFFFFFFFFF, (@current_value >> 64) & 0xFFFFFFFF].pack('Q<L<')
          @current_value += 1
          binary
        end
      end

      def exhausted?
        @current_value >= (MAX_VALUE - REKEY_THRESHOLD)
      end

      def self.random
        RbNaCl::Random.random_bytes(SIZE)
      end
    end
  end
end