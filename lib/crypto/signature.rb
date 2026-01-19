
require 'rbnacl'

module HOVPN
  module Crypto
    
    class Signature
      attr_reader :verify_key

      
      def initialize(seed: nil, verify_only_key: nil)
        if seed
          @signing_key = RbNaCl::SigningKey.new(seed)
          @verify_key  = @signing_key.verify_key
        elsif verify_only_key
          @signing_key = nil
          @verify_key  = RbNaCl::VerifyKey.new(verify_only_key)
        else
          @signing_key = RbNaCl::SigningKey.generate
          @verify_key  = @signing_key.verify_key
        end
      rescue RbNaCl::LengthError
        raise HOVPN::Core::Errors::CryptoError, "Invalid key length (expected 32 bytes)"
      end

      def sign(message)
        raise HOVPN::Core::Errors::CryptoError, "Read-only mode: signing key missing" unless @signing_key
        
        @signing_key.sign(message)
      end

      
      def valid?(message, signature)
        @verify_key.verify(signature, message)
        true
      rescue RbNaCl::CryptoError, RbNaCl::LengthError
        false
      end

   

      def public_key_hex
        @verify_key.to_bytes.unpack1('H*')
      end

      def secret_seed_hex
        @signing_key&.to_bytes&.unpack1('H*')
      end

     
      def wipe!
        if @signing_key
          
          @signing_key = nil 
        end
        @verify_key = nil
        GC.start
      end

      
      def inspect
        "#<#{self.class}:0x#{object_id.to_s(16)} mode=#{@signing_key ? 'Read/Write' : 'Verify-Only'}>"
      end
    end
  end
end