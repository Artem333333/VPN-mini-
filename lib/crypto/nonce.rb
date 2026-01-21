require 'rbnacl'

module HOVPN
  module Crypto
    class Nonce
      SIZE = 12

   
      def self.random
        RbNaCl::Random.random_bytes(SIZE)
      end

    
      def self.increment(current_nonce)
        num = current_nonce.unpack1('Q<') 
        [num + 1].pack('Q<') + current_nonce[8..11] 
      end
    end
  end
end