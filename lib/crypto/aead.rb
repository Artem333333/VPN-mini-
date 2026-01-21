# frozen_string_literal: true
require 'rbnacl'

module HOVPN
  module Crypto
    class AEAD
      def initialize(key)
        @cipher = RbNaCl::AEAD::ChaCha20Poly1305IETF.new(key)
      end

      def decrypt(nonce, ciphertext, ad = "")
        @cipher.decrypt(nonce, ciphertext, ad)
      rescue RbNaCl::CryptoError
        nil
      end
    end
  end
end