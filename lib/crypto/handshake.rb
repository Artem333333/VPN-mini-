
require_relative 'keypair'
require_relative 'hkdf'
require_relative 'nonce'

module HOVPN
  module Crypto
    class Handshake
      attr_reader :state

      def initialize(logger, identity_key, psk)
        @logger = logger
        @identity_key = identity_key 
        @psk = psk
        @ephemeral_key = HOVPN::Crypto::KeyPair.new 
        @state = :uninitiated
      end

    
      def create_initiation_packet
        @state = :sent_initiation
        {
          type: 'INIT',
          ephemeral_pub: @ephemeral_key.public_hex,
          static_pub: @identity_key.public_hex,
          timestamp: Time.now.to_i
        }
      end


      def process_initiation(remote_ephemeral_hex, remote_static_hex)

        shared_e = @ephemeral_key.shared_secret(remote_ephemeral_hex)
        shared_s = @identity_key.shared_secret(remote_static_hex)

   
        mix = shared_e + shared_s + @psk
        
        master_secret = HOVPN::Crypto::HKDF.derive(mix, info: "HOVPN_V1_KEY_EXCHANGE")
        
     
        keys = {
          send_key: HOVPN::Crypto::HKDF.derive(master_secret, info: "TX_KEY", length: 32),
          recv_key: HOVPN::Crypto::HKDF.derive(master_secret, info: "RX_KEY", length: 32)
        }
        
        @state = :established
        keys
      end
    end
  end
end