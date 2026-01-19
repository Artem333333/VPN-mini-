
require 'yaml'
require 'singleton'
require 'async'
require 'async/io'
require 'concurrent-ruby'
require 'etc' 

module HOVPN
  
  module Core
    
    class Application
      
      include Singleton

      attr_reader :config, :logger, :state_machine, :sessions, 
                  :start_time, :worker_pool, :diagnostics

      def initialize
        @config = {}
        @sessions = Concurrent::Hash.new
        @worker_pool = []
        @diagnostics = Concurrent::Hash.new
        @running = false
        @start_time = nil
      
      end

      def bootstrap!(config_path)
       
        unless File.exist?(config_path)
          
          raise "CRITICAL: Configuration file missing at #{config_path}"
        
        end

        @config = load_and_validate_config(config_path)
        @logger = HOVPN::Core::Logger.new(@config[:logging] || {})
        @logger.separator
        @logger.info("HOVPN Engine v#{HOVPN::VERSION rescue '0.1.0'} is warming up...")

        @state_machine = HOVPN::Core::StateMachine.new(@logger)
        
        
        setup_logic_rules!

        perform_system_check!

        @start_time = Time.now
        @logger.info("Bootstrap complete. System is stable.")
      
      end

      def run!
        return if @running
        @running = true
        
        @state_machine.transition_to(:handshaking)
        @logger.info("Entering primary event loop...")

        Async do |task|
          setup_signal_handlers

        
          @worker_pool << task.async { maintenance_worker }
          @worker_pool << task.async { connectivity_monitor }

          @logger.info("Engine is humming. Active Workers: #{@worker_pool.size}")
          
          
          @worker_pool.each(&:wait)
        
        end
      
      rescue StandardError => e
        @logger.exception(e, "Engine crashed during runtime")
        shutdown!
      
      end

      def shutdown!
        return unless @running
        @logger.warn("Shutdown initiated. Cleaning up sessions...")

        @state_machine.transition_to(:disconnected) rescue nil
        
        @sessions.each_value(&:destroy_keys!)
        @sessions.clear
        @running = false
        
        uptime_total = (Time.now - @start_time).to_i rescue 0
        @logger.info("HOVPN process terminated. Total uptime: #{uptime_total}s")
        exit(0)
      
      end

      private

     
      def setup_logic_rules!
        
        @state_machine.add_guard(:active) do
          
          if @sessions.empty?
            @logger.warn("Guard: Transition to ACTIVE denied - No sessions established")
            false
          else
            true
          
          end
        
        end

        
        @state_machine.on_enter(:error) do
          @logger.error("System entered ERROR state. Resetting network stacks...")
         
        
        end
      
      end

      def load_and_validate_config(path)
        raw_config = YAML.load_file(path)
        config = raw_config.transform_keys(&:to_sym)

        required = [:network, :crypto]
        missing = required - config.keys
        raise "Invalid Config: Missing sections #{missing}" unless missing.empty?

        config
      
      end

      def perform_system_check!
        @diagnostics[:os] = RUBY_PLATFORM
        @diagnostics[:cpus] = Etc.nprocessors
        @diagnostics[:user] = Etc.getlogin
        @diagnostics[:ruby_version] = RUBY_VERSION
        @diagnostics[:project_root] = Dir.pwd

        @logger.info("System Info: [OS: #{@diagnostics[:os]}] [CPUs: #{@diagnostics[:cpus]}] [User: #{@diagnostics[:user]}]")
        
        check_windows_environment if RUBY_PLATFORM =~ /mingw|mswin/
      
      end

      def check_windows_environment
        wintun_dll = File.join(Dir.pwd, 'native', 'wintun.dll')
        @diagnostics[:wintun_exists] = File.exist?(wintun_dll)
        
        unless @diagnostics[:wintun_exists]
          @logger.error("Wintun driver MISSING at #{wintun_dll}. Virtual adapter will fail!")
        
        end
      
      end

      def setup_signal_handlers
        ['INT', 'TERM'].each do |sig|
          trap(sig) do
            @logger.warn("Signal #{sig}