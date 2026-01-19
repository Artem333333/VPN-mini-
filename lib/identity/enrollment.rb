
require 'json'
require 'base64'
require 'rbnacl'

module HOVPN
  module Identity
   
    class Enrollment
      attr_reader :device

      def initialize(device)
        @device = device
      end

      
      def generate_invite(ttl_hours: 24)
        payload = {
          srv_n: @device.name,
          srv_k: @device.keystore.key.public_hex,
          srv_f: @device.keystore.key.fingerprint,
          exp: (Time.now + ttl_hours * 3600).to_i,
          caps: @device.manifest[:capabilities], 
          v: '1.1'
        }.to_json

   
        signature = @device.keystore.key.sign(payload)

      
        token_bin = signature + payload
        Base64.urlsafe_encode64(token_bin)
      end


      def join!(token)
        raw_bin = Base64.urlsafe_decode64(token)

        
        sig = raw_bin[0..63]
        json_payload = raw_bin[64..-1]

        data = JSON.parse(json_payload, symbolize_names: true)

        raise 'Token expired' if Time.now.to_i > data[:exp]

      
        verify_server_integrity!(data[:srv_k], sig, json_payload)

        @device.trust_store.authorize_client(
          name: data[:srv_n],
          public_hex: data[:srv_k]
        )

        puts "[Enrollment] Verified & Joined: #{data[:srv_n]}"
        data
      end

    
      def generate_client_response
        {
          cli_n: @device.name,
          cli_k: @device.keystore.key.public_hex,
          cli_f: @device.keystore.key.fingerprint
        }.to_json
      end

      private

      def verify_server_integrity!(pub_hex, sig, message)
        verify_key = RbNaCl::VerifyKey.new([pub_hex].pack('H*'))
        verify_key.verify(sig, message)
      rescue RbNaCl::BadSignatureError
        raise 'CRITICAL: Invite token signature is invalid! Possible MITM attack.'
      end
    end
  end
end
