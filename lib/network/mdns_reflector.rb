require 'socket'
require 'ipaddr'

module HOVPN
  module Network
    class MDNSReflector
      MULTICAST_ADDR = "224.0.0.251"
      PORT = 5353

      def initialize(logger, tun_adapter)
        @logger = logger
        @tun_adapter
      end
    
      def start!
        @logger.info("mDNS: Launching a smart home proxy...")

        Thread.new do
          ip = IPAddr.new(MULTICAST_ADDR).hton + IPAddr.new("0.0.0.0").hton
          sock = UDPSocket.new
          sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, ip)
          sock.bind("0.0.0.0", PORT)
          
          loop do
            data, _ = sock.recvfrom(2048)
            @tun.write_packet(data)
          end
        end
      end

    end

  end
end