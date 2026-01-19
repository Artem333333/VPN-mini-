
require 'fileutils'
require 'etc'

module HOVPN
  
  module Core
    
    module Daemon
      
      class << self
        def daemonize!(pid_file, logger, options = {})
          @logger = logger
          @pid_file = pid_file
          @options = options

          check_existing_process!
          set_process_name("hovpn-core: initializing")
          @logger.info("Daemon: Preparing environment for background execution...")

          
          exit if fork
          Process.setsid
          exit if fork

          write_pid_file
          tune_system_resources
          
          Dir.chdir('/')
          File.umask(0)
          
          redirect_io!
          
          set_process_name("hovpn-core: active [#{Process.pid}]")
          @logger.info("Daemon: Transformation complete. Running as system service.")

          at_exit { perform_final_cleanup }
        
        end

        def running?(pid_file)
          return false unless File.exist?(pid_file)
          pid = File.read(pid_file).to_i
          Process.kill(0, pid)
          true
        rescue Errno::ESRCH, Errno::ENOENT
          false
        
        end

        def send_signal(pid_file, signal = 'TERM')
          if running?(pid_file)
            pid = File.read(pid_file).to_i
            Process.kill(signal, pid)
            return true
          
          end
          false
        
        end

        private

        def tune_system_resources
          @logger.debug("Daemon: Tuning system resource limits...")
          
          if defined?(Process::RLIMIT_NOFILE)
            begin
              Process.setrlimit(Process::RLIMIT_NOFILE, 65535)
              @logger.debug("Daemon: NOFILE limit set to 65535")
            rescue StandardError => e
              @logger.warn("Daemon: Could not set NOFILE limit: #{e.message}")
            
            end
         
          end

          begin
            Process.setpriority(Process::PRIO_PROCESS, 0, -5)
            @logger.debug("Daemon: Process priority increased")
          rescue StandardError
            @logger.debug("Daemon: Priority tuning skipped (needs root)")
          
          end
        
        end

        def set_process_name(name)
          $0 = name
        
        end

        def check_existing_process!
          if running?(@pid_file)
            pid = File.read(@pid_file).strip
            @logger.fatal("Daemon: Process already running with PID #{pid}")
            exit(1)
          
          end
        
        end

        def write_pid_file
         
          FileUtils.mkdir_p(File.dirname(@pid_file))
          File.write(@pid_file, Process.pid.to_s)
        rescue StandardError => e
          @logger.error("Daemon: Failed to write PID file: #{e.message}")
        
        end

        def redirect_io!
          $stdin.reopen('/dev/null')
          err_log = @options[:error_log] || '/dev/null'
          
          $stdout.reopen(err_log, 'a')
          $stderr.reopen($stdout)
          $stdout.sync = true
        
        end

        def perform_final_cleanup
          if File.exist?(@pid_file) && File.read(@pid_file).to_i == Process.pid
            File.delete(@pid_file)
            @logger.info("Daemon: PID file cleaned up. Shutdown complete.")
          
          end
        
        end
      
      end
    
    end
  
  end

end