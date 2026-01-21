
require 'socket'
require 'async'
require 'async/io'

module HOVPN
  module Network
    class UDPStack
      def initialize(logger, host: '0.0.0.0', port: 4444)
        @logger = logger
        @host = host
        @port = port
        @socket = nil
      end

     
      def bind!
        @socket = Async::IO::UDPSocket.new
        @socket.bind(@host, @port)
        @logger.info("UDP Stack: Слушаем на #{@host}:#{@port} (Async mode)")
      end

    
      def listen
        @logger.info("UDP Stack: Цикл обработки запущен.")
        
        loop do
          
          data, addr = @socket.recvfrom(65_535)
          ip = addr[3]
          port = addr[1]

         
          Async do
            HOVPN::Application.instance.process_incoming_packet(data, ip, port)
          end
        rescue StandardError => e
          @logger.error("UDP Stack Error: #{e.message}")
        end
      end

     
      def send_data(data, ip, port)
        @socket.send(data, 0, ip, port)
      rescue StandardError => e
        @logger.error("UDP Send Error to #{ip}:#{port} -> #{e.message}")
      end
    end
  end
end