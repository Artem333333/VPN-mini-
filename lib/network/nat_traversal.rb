
require 'timeout'

module HOVPN
  module Network
  
    class NATTraversal
      
      STATES = { idle: 0, punching: 1, established: 2, failed: 3 }.freeze

      def initialize(udp_driver)
        @driver = udp_driver
        @attempts = 10 
        @interval = 0.3 
        @state = :idle
      end

     
      def punch!(remote_ip, remote_port, session_id)
        @state = :punching
        puts "[NAT] Initializing aggressive hole punching to #{remote_ip}:#{remote_port}..."
        
       
        punch_packet = Packet.new(
          type: :keeplive, 
          session_id: session_id, 
          payload: "PUNCH"
        ).to_binary

        @attempts.times do |i|
          break if @state == :established

          begin
            @driver.send(punch_packet, remote_ip, remote_port)
            puts "[NAT] [Attempt #{i+1}/#{@attempts}] Outgoing punch sent to #{remote_ip}"
            sleep @interval
          rescue StandardError => e
            puts "[NAT] Critical Send Error: #{e.message}"
          end
        end

        finalize_punching
      end

     
      def confirm_punch!(source_ip, source_port)
        @state = :established
        puts "[NAT] SUCCESS! Hole punched for #{source_ip}:#{source_port}. Direct P2P tunnel active."
      end

      private

      def finalize_punching
        unless @state == :established
          @state = :failed
          puts "[NAT] Sequence finished. If no traffic, consider using TCP relay."
        end
      end
    end
  end
end