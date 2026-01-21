
require 'singleton'
require 'yaml'
require 'json'
require_relative 'core/logger'
require_relative 'core/session_manager'
require_relative 'network/udp_stack'
require_relative 'crypto/keypair'
require_relative 'crypto/handshake'

module HOVPN
  class Application
    include Singleton

    attr_reader :config, :logger, :sessions, :identity_key

    def initialize
      @running = false
    end

    def bootstrap!
      load_config
      @logger = HOVPN::Core::Logger.new
      @logger.info("HOVPN: Запуск оркестратора...")

      prepare_keys
      @sessions = HOVPN::Core::SessionManager.new(@logger)
      @udp_stack = HOVPN::Network::UDPStack.new(@logger, port: @config['listen_port'])

      @logger.info("HOVPN: Система готова. Fingerprint узла: #{@identity_key.fingerprint}")
    end

    
    def process_incoming_packet(data, ip, port)
      
      session = @sessions.find_session(ip)

      if session
        handle_data_packet(session, data)
      else
        
        handle_potential_handshake(data, ip, port)
      end
    rescue StandardError => e
      @logger.error("Application Error: #{e.message}")
    end

    private

    
    def handle_data_packet(session, data)
      decrypted = session.decrypt_packet(data)
      return unless decrypted

      @logger.debug("Принят пакет от #{session.client_id}: #{decrypted.bytesize} байт")
      
    end

    def handle_potential_handshake(data, ip, port)
      
      begin
        payload = JSON.parse(data)
      rescue JSON::ParserError
        return @logger.warn("UDP: Неавторизованный шум от #{ip}:#{port}")
      end

      if payload['type'] == 'INIT'
        @logger.info("Handshake: Получен запрос от #{ip}")

        
        unless authorized_client?(payload['static_pub'])
          return @logger.error("Handshake: Отказ! Ключ #{payload['static_pub'][0..10]}... не в белом списке.")
        end

      
        handshake = HOVPN::Crypto::Handshake.new(@logger, @identity_key, @config['psk'])
        keys = handshake.process_initiation(payload['ephemeral_pub'], payload['static_pub'])

      
        @sessions.establish_session(ip, keys)
        
        
      end
    end

    def authorized_client?(public_hex)
      
      true 
    end

    def load_config
      @config = YAML.load_file('config.yml')
    end

    def prepare_keys
      path = @config['private_key_path']
      if File.exist?(path)
        raw_key = [File.read(path).strip].pack('H*')
        @identity_key = HOVPN::Crypto::KeyPair.new(raw_key)
      else
        @identity_key = HOVPN::Crypto::KeyPair.new
        File.write(path, @identity_key.private_hex)
      end
    end
  end
end