require 'socket'

module HomeNexus
  module Discovery
    class MdnsReflector
      def self.start
        Thread.new do
          puts "[*] mDNS Рефлектор запущен (Thread/SmartHome)"
          begin
            u = UDPSocket.new
            u.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
            u.bind('0.0.0.0', 5353)
            loop do
              msg, sender = u.recvfrom(2048)
            end
          rescue => e
            puts "Ошибка mDNS: #{e.message}"
          end
        end
      end
    end
  end
end