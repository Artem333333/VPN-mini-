
require 'socket'
require 'securerandom'
require 'etc'

module HOVPN
  module Identity
    class Device
      STATES = [:init, :booting, :ready, :error, :dead].freeze
      

      attr_reader :name, :keystore, :trust_store, :status, :metadata, :started_at

      def initialize(name: nil, keystore:, trust_store:)
        @name = name || "hovpn-node-#{SecureRandom.hex(4)}"
        @keystore = keystore
        @trust_store = trust_store
        @status = :init
        @lock = Mutex.new

        @metadata = {
          os: RUBY_PLATFORM,
          cpus: Etc.nprocessors,
          pid: Process.pid,
          ruby_version: RUBY_VERSION
        }
      end

      def boot!
        @lock.synchronize do
          return if @status == :ready
          @status = :booting
          begin
            check_system_entropy!
            initialize_resources!
            enforce_security_limits!

            @status = :ready
            @started_at = Time.now
            log_boot_success
          rescue StandardError => e
            @status = :error
            raise "Boot failed: #{e.message}"
          end
        end
      end

      def manifest
        ensure_ready!
        {
          node_id: @name,
          public_key: @keystore.key.public_hex,
          fingerprint: @keystore.key.fingerprint,
          capabilities: [:aead_aes_gcm, :x25519, :lz4_compression],
          timestamp: Time.now.to_i
        }
      end

      def stats
        {
          name: @name,
          status: @status,
          uptime: @started_at ? (Time.now - @started_at).round(2) : 0,
          memory: current_memory_usage,
          load_avg: (File.read('/proc/loadavg').split[0..2].join(' ') rescue "N/A")
        }
      end

      def shutdown!
        @lock.synchronize do
          @status = :dead
          @keystore.wipe_from_memory!
          @trust_store.clients.clear
          GC.start
          puts "[Device] #{@name} shut down safely."
        end
      end

      private

      def enforce_security_limits!
        Process.setrlimit(:NOFILE, 10_000) rescue nil
        
        Process.setrlimit(:CORE, 0) rescue nil
        
        Process.setrlimit(:AS, 1024 * 1024 * 1024) rescue nil
        
        Process.setpriority(Process::PRIO_PROCESS, 0, -10) rescue nil
      end

      def check_system_entropy!
        path = '/proc/sys/kernel/random/entropy_avail'
        if File.exist?(path)
          avail = File.read(path).to_i
          puts "[Device] Low entropy warning: #{avail}" if avail < 128
        end
      end

      def initialize_resources!
        @keystore.load_or_generate! unless @keystore.unlocked?
        @trust_store.load!
      end

      def current_memory_usage
        `ps -o rss= -p #{Process.pid}`.strip.to_i / 1024
      rescue
        0
      end

      def ensure_ready!
        raise "Device not ready (status: #{@status})" unless @status == :ready
      end

      def log_boot_success
        puts "\n" + ("=" * 50)
        puts "HOVPN DEVICE READY: #{@name}"
        puts "FINGERPRINT: #{@keystore.key.fingerprint}"
        puts "OS: #{@metadata[:os]} | CPUs: #{@metadata[:cpus]}"
        puts ("=" * 50) + "\n"
      end
    end
  end
end