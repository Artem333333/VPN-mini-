require 'rbnacl'
require 'base64'
require 'fileutils'
require 'openssl'
require 'json'

module HOVPN
  module Crypto
    class KeyPair
      KEY_SIZE = 32
      MAX_KEY_AGE = 2_592_000

      attr_reader :public_key, :created_at, :fingerprint, :metadata

      def initialize(private_key_raw = nil, metadata = {})
        @created_at = Time.now
        @metadata = metadata

        ensure_secure_random!

        if private_key_raw
          validate_key_size!(private_key_raw)
          @private_key = RbNaCl::PrivateKey.new(private_key_raw)

          wipe_string!(private_key_raw)
        else
          @private_key = RbNaCl::PrivateKey.generate
        end

        @public_key = @private_key.public_key
        @fingerprint = RbNaCl::Hash.sha256(@public_key.to_bytes)[0..15].unpack1('H*')
      rescue RbNaCl::CryptoError => e
        raise HOVPN::Core::Errors::CryptoError, "Fatal Crypto Failure: #{e.message}"
      end

      def shared_secret(remote_public_hex)
        remote_raw = [remote_public_hex.strip].pack('H*')
        validate_key_size!(remote_raw)

        RbNaCl::GroupElements::Curve25519.new(remote_raw)
                                         .mult(@private_key.to_bytes)
      rescue StandardError => e
        raise HOVPN::Core::Errors::CryptoError, "Handshake Failed: #{e.message}"
      end

      def save_encrypted!(path, password)
        salt = OpenSSL::Random.random_bytes(16)

        iter = 100_000

        cipher_key = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, iter, 32, 'sha256')

        cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
        cipher.key = cipher_key
        iv = cipher.random_iv

        encrypted_data = cipher.update(private_hex) + cipher.final
        auth_tag = cipher.auth_tag

        payload = {
          v: 2,
          salt: Base64.strict_encode64(salt),
          iv: Base64.strict_encode64(iv),
          tag: Base64.strict_encode64(auth_tag),
          iter: iter,
          data: Base64.strict_encode64(encrypted_data),
          created_at: @created_at.to_i
        }

        FileUtils.mkdir_p(File.dirname(path))

        File.open(path, 'w', 0o600) { |f| f.write(payload.to_json) }
      ensure
        wipe_string!(cipher_key) if defined?(cipher_key)
      end

      def private_hex
        @private_key.to_bytes.unpack1('H*')
      end

      def public_hex
        @public_key.to_bytes.unpack1('H*')
      end

      def wipe!
        @private_key = nil
        GC.start
      end

      private

      def wipe_string!(str)
        return unless str.is_a?(String)

        str.replace("\x00" * str.bytesize)
      end

      def ensure_secure_random!
        RbNaCl::Random.random_bytes(1)
      rescue StandardError
        raise 'CRITICAL: System entropy source is unavailable'
      end

      def validate_key_size!(raw_bytes)
        return if raw_bytes.bytesize == KEY_SIZE

        raise HOVPN::Core::Errors::CryptoError, "Invalid key size: #{raw_bytes.bytesize}"
      end
    end
  end
end
