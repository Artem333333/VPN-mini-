require 'socket'
require 'io/wait'

module HOVPN
  module Network
    class UDPStack
      MAX_DATAGRAM_SIZE = 65_507
      SO_RCVBUF_SIZE    = 4 * 1024 * 1024 

      attr_reader :port, :host, :packets_in, :packets_out

      def initialize(logger, host: '0.0.0.0', port: 4444)
        @host = host
        @port = port
        @logger = logger
        @socket = UDPSocket.new
        @running = false
        @packets_in = 0
        @packets_out = 0
      end

      def bind!
        @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVBUF, SO_RCVBUF_SIZE)
        @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
        @socket.bind(@host, @port)
        @running = true
        @logger.info("Network: UDP Stack listening on #{@host}:#{@port}")
      end

      def listen(session_manager)
        @logger.debug("Network: Entering receive loop...")
        
        loop do
          @socket.wait_readable 
          
          begin
            data, sender = @socket.recvfrom_nonblock(MAX_DATAGRAM_SIZE)
            @packets_in += 1
            
            ip = sender[3]
            port = sender[1]

       
            session = session_manager.find_session(ip, port)

            if session
              @logger.debug("Network: Packet from #{ip}:#{port} -> Routing to session #{session.session_id}")
          
            else
              @logger.warn("Network: Packet from unknown peer #{ip}:#{port} (Dropped)")
            end
            
          rescue IO::WaitReadable
            retry
          rescue StandardError => e
            @logger.error("Network: Error in listen loop: #{e.message}")
          end
        end
      end
    end
  end
end