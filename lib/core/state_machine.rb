require 'concurrent-ruby'
require 'securerandom'

module HOVPN
  
  module Core
    
    class StateMachine
      
      STATES = %i[init handshaking active rekeying error disconnected].freeze

      GRAPH = {
        init:         [:handshaking, :error],
        handshaking:  [:active, :error, :disconnected],
        active:       [:rekeying, :disconnected, :error],
        rekeying:     [:active, :error, :disconnected],
        error:        [:init, :disconnected],
        disconnected: [:init]
      }.freeze

      attr_reader :state, :history, :stats, :last_change

      def initialize(logger)
        @logger = logger
        @state = :init
        @last_change = Time.now
        @lock = Mutex.new
        
      
        @stats = Concurrent::Hash.new { |h, k| h[k] = 0.0 }
        @history = Concurrent::Array.new
        
       
        @guards = Concurrent::Hash.new { |h, k| h[k] = [] }
        @on_enter = Concurrent::Hash.new { |h, k| h[k] = [] }
        @on_transition = []
        
        @logger.debug("StateMachine: Engine initialized in INIT state")
      
      end   

    
      def trigger(event_name, to_state)
        @lock.synchronize do
          return false if @state == to_state

          @logger.debug("StateMachine: Event '#{event_name}' attempting transition to #{to_state}")

          
          unless GRAPH[@state]&.include?(to_state) || to_state == :error
            @logger.error("StateMachine: Violation! Cannot move #{@state} -> #{to_state}")
            return false
          
          end

         
          unless passing_guards?(to_state)
            @logger.warn("StateMachine: Transition to #{to_state} blocked by guards")
            return false
          
          end

          perform_transition(to_state, event_name)
          true
        
        end
      
      end

      
      def add_guard(to_state, &block)
        @guards[to_state] << block
      
      end

      
      def on_enter(state, &block)
        @on_enter[state] << block
      
      end

     
      def after_transition(&block)
        @on_transition << block
      
      end

     

      def uptime_in_current_state
        Time.now - @last_change
      
      end

      def healthy?
        @state != :error
      
      end

      
      def telemetry
        current_stats = @stats.dup
        current_stats[@state] += uptime_in_current_state
        current_stats
      
      end

      private

      def perform_transition(to_state, event)
        old_state = @state
        duration = uptime_in_current_state
        
      
        @stats[old_state] += duration
        
        @state = to_state
        @last_change = Time.now

        
        @logger.info("STATE_CHANGE: [#{old_state.upcase}] --(#{event})--> [#{to_state.upcase}] (Stayed in #{old_state}: #{duration.round(2)}s)")

        
        @history << {
          id: SecureRandom.uuid,
          from: old_state, to: to_state,
          event: event, at: @last_change
        }
        @history.shift if @history.size > 100

        
        execute_hooks(to_state, old_state)
      
      end

      def passing_guards?(to_state)
        @guards[to_state].all? do |guard|
          guard.call == true
        rescue StandardError => e
          @logger.error("StateMachine: Guard error: #{e.message}")
          false
        
        end
      
      end

      def execute_hooks(to_state, old_state)
       
        @on_enter[to_state].each { |blk| blk.call rescue nil }
        
        @on_transition.each { |blk| blk.call(old_state, to_state) rescue nil }
      
      end
    
    end
  
  end

end