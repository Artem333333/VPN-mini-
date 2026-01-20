
require 'yaml'
require 'singleton'
require 'async'
require 'concurrent-ruby'
require 'etc'

require_relative 'errors'
require_relative 'session'
require_relative 'session_manager'
require_relative '../network/udp_stack'

module HOVPN
  module Core
    class Application
      include Singleton

      attr_reader :config, :logger, :state_machine, :session_manager, 
                  :udp_stack, :worker_pool

      def initialize
        @config = {}
        @worker_pool = []
        @running = false
      end

      def bootstrap!(config_path)

        @config = load_config(path: config_path)
        
      
        @logger = HOVPN::Core::Logger.new(@config[:logging] || {})
        @logger.separator
        @logger.info("HOVPN Engine: Starting bootstrap process...")

       
        @state_machine    = HOVPN::Core::StateMachine.new(@logger)
        @session_manager  = HOVPN::Core::SessionManager.new(@logger)
        
        network_cfg = @config[:network] || {}
        @udp_stack = HOVPN::Network::UDPStack.new(
          @logger, 
          host: network_cfg[:host] || '0.0.0.0', 
          port: network_cfg[:port] || 4444
        )

        perform_system_check!
        
        @start_time = Time.now
        @logger.info("Bootstrap complete. System is stable.")
      end

      def run!
        return if @running
        @running = true
        
        @state_machine.trigger(:start, :handshaking)
        @logger.info("Entering primary event loop...")

        Async do |task|
          setup_signal_handlers
          
          @udp_stack.bind!

          @worker_pool << task.async { @udp_stack.listen(@session_manager) }

          @worker_pool << task.async { maintenance_worker }

          @worker_pool << task.async { monitor_worker }

          @logger.info("[SYSTEM READY] Port: #{@udp_stack.port} | Workers: #{@worker_pool.size}")
          @worker_pool.each(&:wait)
        end
      rescue StandardError => e
        @logger.exception(e, "Engine CRASHED")
        shutdown!
      end

      def shutdown!
        return unless @running
        @logger.warn("Shutdown initiated. Cleaning up resources...")
        @state_machine.trigger(:stop, :disconnected) rescue nil
        @running = false
        
        uptime = (Time.now - @start_time).to_i rescue 0
        @logger.info("HOVPN Stopped. Uptime: #{uptime}s | Active Sessions: #{@session_manager.active_count}")
        exit(0)
      end

      private

      def maintenance_worker
        loop do
          sleep 60
          removed = @session_manager.cleanup!
          @logger.debug("Maintenance: Cleaned up #{removed} expired sessions") if removed > 0
        end
      end

      def monitor_worker
        loop do
          sleep 30
          @logger.debug("Heartbeat: Sessions: #{@session_manager.active_count} | Packets In: #{@udp_stack.packets_in}")
        end
      end

      def load_config(path:)
        YAML.load_file(path).transform_keys(&:to_sym) rescue {network: {port: 4444}}
      end

      def perform_system_check!
        @logger.info("System Check: [OS: #{RUBY_PLATFORM}] [CPUs: #{Etc.nprocessors}]")
        check_wintun
      end

      def check_wintun
        wintun_path = File.join(Dir.pwd, 'native', 'wintun.dll')
        unless File.exist?(wintun_path)
          @logger.error("Wintun driver MISSING at #{wintun_path}. VPN tunneling will be unavailable.")
        end
      end

      def setup_signal_handlers
        ['INT', 'TERM'].each { |sig| trap(sig) { shutdown! } }
      end
    end
  end
end