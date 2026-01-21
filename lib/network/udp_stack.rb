require 'socket'

module HOVPN
  module Network
    class UDPStack
      def initialize(logger, host: '0.0.0.0', port: 4444)
        @logger = logger
        @socket = UDPSocket.new
        @host = host
        @port = port
      end

      def bind!
        @socket.bind(@host, @port)
        @logger.info("UDP: Слушаем на #{@host}:#{@port}")
      end

      def listen(session_manager)
        loop do
          data, sender = @socket.recvfrom(65_535)
          ip = sender[3]
          port = sender[1]

          session = session_manager.find_session(ip, port)
          if session
            decrypted = session.decrypt_packet(data)
            @logger.debug("UDP: Получен пакет от #{ip}, расшифровано: #{decrypted.size} байт") if decrypted
          else
            @logger.warn("UDP: Неизвестный пакет от #{ip}:#{port}")
          end
        rescue StandardError => e
          @logger.error("UDP Error: #{e.message}")
        end
      end
    end
  end
end
