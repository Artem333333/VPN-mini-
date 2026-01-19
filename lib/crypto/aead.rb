
require 'rbnacl'

module HOVPN
  module Crypto
    
    class AEAD
      TAG_SIZE   = 16
      NONCE_SIZE = 12 
      KEY_SIZE   = 32

      attr_reader :last_usage

      def initialize(key)
        validate_key!(key)
        @key = key.dup.freeze 
        @cipher = RbNaCl::AEAD::ChaCha20Poly1305IETF.new(@key)
        @last_usage = Time.now
        @last_nonce = nil
        @lock = Mutex.new 
      rescue RbNaCl::LengthError
        raise HOVPN::Core::Errors::CryptoError, "AEAD Initialization: Invalid key length"
      end

      
      def encrypt(nonce, plaintext, ad = "")
        @lock.synchronize do
          validate_nonce!(nonce)
          prevent_nonce_reuse!(nonce)
          
          @last_usage = Time.now
          @cipher.encrypt(nonce, plaintext, ad)
        end
      rescue RbNaCl::CryptoError => e
        raise HOVPN::Core::Errors::CryptoError, "Encryption failed: #{e.message}"
      end

   
      def decrypt(nonce, ciphertext, ad = "")
        
        @lock.synchronize do
          validate_nonce!(nonce)
          @last_usage = Time.now
          @cipher.decrypt(nonce, ciphertext, ad)
        end
      rescue RbNaCl::CryptoError
        raise HOVPN::Core::Errors::CryptoError, "Integrity failure: data modified or wrong key"
      end

     
      def wipe!
        @lock.synchronize do
          
          if @key.respond_to?(:replace)
            
          end
          @key = nil
          @cipher = nil
          GC.start
        end
      end

      def inspect
        "#<#{self.class}:0x#{object_id.to_s(16)} [CHACHA20-POLY1305 READY]>"
      end

      private

      def validate_key!(key)
        unless key&.bytesize == KEY_SIZE
          raise HOVPN::Core::Errors::CryptoError, "Key must be #{KEY_SIZE} bytes"
        end
      end

      def validate_nonce!(nonce)
        unless nonce&.bytesize == NONCE_SIZE
          raise HOVPN::Core::Errors::CryptoError, "Nonce must be #{NONCE_SIZE} bytes"
        end
      end

      def prevent_nonce_reuse!(nonce)
        if @last_nonce == nonce
          raise HOVPN::Core::Errors::CryptoError, "CRITICAL: Nonce reuse detected for this session!"
        end
        @last_nonce = nonce
      end
    end
  end
end