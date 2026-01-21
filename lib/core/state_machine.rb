module HOVPN
  module Core
    class StateMachine
      attr_reader :current_state

      def initialize(logger)
        @logger = logger
        @current_state = :stopped
      end

      def trigger(event, new_state)
        @logger.info("System: #{event.upcase} -> Transitioning to #{new_state.upcase}")
        @current_state = new_state
      end
    end
  end
end
