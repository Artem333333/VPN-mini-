require 'singleton'
require 'yaml'
require_relative 'core/logger'
require_relative 'core/session_manager'
require_relative 'network/udp_stack'
require_relative 'crypto/keypair'

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
      @logger.info("HOVPN: Инициализация системы...")

    
      prepare_keys


      @sessions = HOVPN::Core::SessionManager.new(@logger)

 
      @udp_stack = HOVPN::Network::UDPStack.new(@logger, port: @config['listen_port'])

      @logger.info("HOVPN: Загрузка завершена. Узел: #{@config['node_name']}")
    end

    def run!
      @running = true
      @logger.info("HOVPN: Двигатель запущен. Слушаем порт #{@config['listen_port']}...")


      Async do |task|
        @udp_stack.bind!
        
        task.async { @udp_stack.listen(@sessions) }
        
      end
    end

    private

    def load_config
      @config = YAML.load_file('config.yml')
    rescue Errno::ENOENT
      puts "Ошибка: Файл config.yml не найден!"
      exit(1)
    end

    def prepare_keys
      path = @config['private_key_path']
      if File.exist?(path)
        raw_key = File.read(path).strip
        @identity_key = HOVPN::Crypto::KeyPair.new([raw_key].pack('H*'))
        @logger.info("HOVPN: Статический ключ загружен (Fingerprint: #{@identity_key.fingerprint})")
      else
        @identity_key = HOVPN::Crypto::KeyPair.new
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, @identity_key.private_hex)
        @logger.warn("HOVPN: Сгенерирован новый статический ключ и сохранен в #{path}")
      end
    end
  end
end