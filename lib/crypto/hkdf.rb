
require 'rbnacl'
require 'openssl'

module HOVPN
  module Crypto
    
    class HKDF
      DIGEST_SIZES = {
        sha256: 32,
        sha512: 64
      }.freeze

      def initialize(salt = nil, hash_algo: :sha256)
        @hash_algo = hash_algo
        @digest_size = DIGEST_SIZES.fetch(hash_algo)
        
        @salt = salt || "\x00" * @digest_size
      end

      
      def self.derive(ikm, salt: nil, info: "", length: 32)
        new(salt).derive(ikm, info: info, length: length)
      end

      def derive(ikm, info: "", length: 32)
        raise HOVPN::Core::Errors::CryptoError, "IKM (Input Keying Material) is empty" if ikm.nil? || ikm.empty?
        
        raise HOVPN::Core::Errors::CryptoError, "Requested length too large" if length > 255 * @digest_size

        
        prk = extract(ikm)

        
        result = expand(prk, info, length)

        
        wipe!(prk)
        result
      rescue StandardError => e
        raise HOVPN::Core::Errors::CryptoError, "HKDF process failed: #{e.message}"
      end

      private

      
      def extract(ikm)
        case @hash_algo
        when :sha256
          RbNaCl::HMAC::SHA256.new(@salt).digest(ikm)
        when :sha512
          OpenSSL::HMAC.digest('sha512', @salt, ikm)
        end
      end

      
      def expand(prk, info, length)
        okm = "".force_encoding('BINARY')
        t = "".force_encoding('BINARY')
        i = 1

        
        engine = @hash_algo == :sha256 ? RbNaCl::HMAC::SHA256.new(prk) : nil

        while okm.bytesize < length
          
          context = t + info + [i].pack('C')
          
          t = if engine
                engine.digest(context)
              else
                OpenSSL::HMAC.digest('sha512', prk, context)
              end

          okm << t
          i += 1
        end

        okm.byteslice(0, length)
      end

      def wipe!(data)
        return unless data.is_a?(String)
        
        data.replace("\x00" * data.bytesize)
      end
    end
  end
end