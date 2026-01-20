require 'monitor'

module HOVPN
  module Network
    class SocketWrapper 
      include MonitorMixin
      attr_reader :remote_host, :remote_port, :last_activity, :stats, :mtu

      DEFAULT_MTU        = 1450
      MIN_MTU            = 1280
      KEEPALIVE_INT      = 15
      CONNECTION_TIMEOUT = 60
      MAX_PPS            = 5000

      def initialize(udp_driver, host, port)
        super() 
        @driver = udp_driver
        @remote_host = host
        @remote_port = port
        @mtu         = DEFAULT_MTU

        @last_activity = Time.now
        @active = true

        @pps_counter    = 0
        @last_pps_reset = Time.now

        @stats = {
          tx_bytes: 0, rx_bytes: 0,
          tx_packets: 0, rx_packets: 0,
          errors: 0, dropped: 0,
          start_time: Time.now
        }
      end

      def send_packet(packet_data)
        return false unless @active
        return drop_packet("Rate limit exceeded") if rate_limited?  

        size = packet_data.bytesize
        if size > @mtu
          return drop_packet("Packet too big: #{size}b > #{@mtu}b")
        end

        synchronize do
          begin
            @driver.send(packet_data, @remote_host, @remote_port)
            update_stats(:tx, size)
            true
          rescue StandardError => e
            @stats[:errors] += 1
            puts "[SocketWrapper] Send error: #{e.message}"
            false
          end 
        end 
      end

      def handle_incoming(data)
        synchronize do
          @last_activity = Time.now
          update_stats(:rx, data.bytesize)
        end
      end

      def alive?
        (Time.now - @last_activity) < CONNECTION_TIMEOUT
      end

      def close!
        @active = false
        synchronize do
          puts "[SocketWrapper] Closing connection to #{@remote_host}:#{@remote_port}"
        end
      end

      private

      def rate_limited?
        now = Time.now
        if (now - @last_pps_reset) > 1
          @pps_counter = 0
          @last_pps_reset = now
        end
        @pps_counter += 1
        @pps_counter > MAX_PPS
      end

      def drop_packet(reason)
        @stats[:dropped] += 1
        
        false
      end

      def update_stats(type, size)
        if type == :tx
          @stats[:tx_bytes] += size
          @stats[:tx_packets] += 1
        else
          @stats[:rx_bytes] += size
          @stats[:rx_packets] += 1
        end
      end
    end 
  end 
end 