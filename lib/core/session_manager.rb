require 'concurrent-ruby'

module HOVPN
  module Core
    class SessionManager
      def initialize(logger)
        @logger = logger
      
        @sessions = Concurrent::Hash.new
        @lock = Mutex.new
      end

      def find_session(ip, port)
        @sessions["#{ip}:#{port}"]
      end

      def add_session(session)
        key = "#{session.endpoint[:ip]}:#{session.endpoint[:port]}"
        @sessions[key] = session
        @logger.info("SessionManager: Registered new session #{session.session_id} for #{key}")
      end

    
      def cleanup!
        count = 0
        @sessions.delete_if do |key, session|
          if session.dead?
            @logger.info("SessionManager: Removing timed out session #{session.session_id}")
            count += 1
            true
          else
            false
          end
        end
        count
      end

      def active_count
        @sessions.size
      end
    end
  end
end