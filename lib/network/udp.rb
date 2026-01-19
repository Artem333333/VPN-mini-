
require 'socket'
require 'io/wait'
require 'logger' 

module HOVPN
  module Network
    class UDP
      MAX_DATAGRAM_SIZE = 65_507
      SO_RCVBUF_SIZE    = 4 * 1024 * 1024 

      attr_reader :port, :host, :logger

      def initialize(host: '0.0.0.0', port: 4444, logger: nil)
        @host = host
        @port = port
        @socket = UDPSocket.new
        @running = false
        
        @logger = logger || default_logger
        
        @packets_in = 0
        @packets_out = 0
      end

      def start
        configure_socket!
        @socket.bind(@host, @port)
        @running = true
        @logger.info("[UDP] Server listening on #{@host}:#{@port}")
      rescue Errno::EADDRINUSE
        @logger.fatal("[UDP] Port #{@port} is already in use by another process!")
        raise
      end

      def receive
        return nil unless @running
        return nil unless @socket.wait_readable(0.01)

        begin
          data, sender = @socket.recvfrom_nonblock(MAX_DATAGRAM_SIZE)
          @packets_in += 1
          
          { data: data, ip: sender[3], port: sender[1] }
        rescue IO::WaitReadable
          nil
        rescue Errno::ECONNREFUSED
          @logger.warn("[UDP] ICMP Port Unreachable received (likely remote peer closed port)")
          nil
        rescue StandardError => e
          log_network_error(e, "Receive")
          nil
        end
      end

      def send_packet(data, ip, port)
        return false unless @running
        
        @socket.send(data, 0, ip, port)
        @packets_out += 1
        true
      rescue Errno::EMSGSIZE
        @logger.error("[UDP] Send failed: Message too long (MTU issue) to #{ip}:#{port}")
        false
      rescue Errno::EHOSTUNREACH
        @logger.error("[UDP] Send failed: Host #{ip} is unreachable")
        false
      rescue StandardError => e
        log_network_error(e, "Send", ip)
        false
      end

      private

    
      def log_network_error(e, operation, target_ip = nil)
        msg = "[UDP] #{operation} Error"
        msg += " to #{target_ip}" if target_ip
        
        case e
        when Errno::EACCES
          @logger.error("#{msg}: Permission denied (Firewall/SELinux?)")
        when Errno::ENOBUFS
          @logger.fatal("#{msg}: System network buffers are full! Lower the traffic or tune the kernel.")
        else
          @logger.error("#{msg}: #{e.class} - #{e.message}")
        end
      end

      def default_logger
        l = Logger.new(STDOUT)
        l.formatter = proc do |severity, datetime, progname, msg|
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
        end
        l
      end

      def configure_socket!
        @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVBUF, SO_RCVBUF_SIZE)
        @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
      end
    end
  end
end