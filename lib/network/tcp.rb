require 'socket'
require 'thread'
require 'io/wait'

module HOVPN
  module Network
    
    class TCP
      attr_reader :host, :port, :connected, :stats

      MAX_FRAME_SIZE = 16384 
      READ_TIMEOUT   = 10    

      def initialize(host, port)
        @host = host
        @port = port
        @socket = nil
        @connected = false
        @lock = Mutex.new
        @stats = { tx: 0, rx: 0, reconnects: 0 }
      end

    
      def connect(timeout: 5)
        return true if @connected

        @lock.synchronize do
          begin
           
            @socket = Socket.tcp(@host, @port, connect_timeout: timeout)
            
            
            @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
            
            @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, 1)
            
            @connected = true
            @stats[:reconnects] += 1
            puts "[TCP] High-performance connection established to #{@host}"
          rescue StandardError => e
            @connected = false
            puts "[TCP] Connection Failed: #{e.message}"
          end
        end
        @connected
      end

  
      def send_frame(data)
        return false unless @connected

        size = data.bytesize
        if size > MAX_FRAME_SIZE
          puts "[TCP] Critical: Attempted to send frame too large (#{size}b)"
          return false
        end

        begin
          
          frame = [size].pack("n") << data
          
       
          @lock.synchronize do
            @socket.write(frame)
          end
          @stats[:tx] += size
          true
        rescue StandardError => e
          handle_fault("Write error: #{e.message}")
          false
        end
      end

     
      def read_frame
        return nil unless @connected

        begin
          
          return nil unless @socket.wait_readable(READ_TIMEOUT)

         
          header = @socket.read(2)
          return handle_fault("Remote closed connection") if header.nil?

          length = header.unpack1("n")

          
          if length > MAX_FRAME_SIZE || length <= 0
            return handle_fault("Invalid frame size received: #{length}b")
          end

         
          payload = @socket.read(length)
          return handle_fault("Incomplete frame received") if payload.nil? || payload.bytesize < length

          @stats[:rx] += length
          payload
        rescue StandardError => e
          handle_fault("Read error: #{e.message}")
          nil
        end
      end

      def disconnect
        @lock.synchronize do
          @socket&.close rescue nil
          @socket = nil
          @connected = false
          puts "[TCP] Link closed."
        end
      end

      private

      def handle_fault(reason)
        puts "[TCP] Connection fault: #{reason}"
        disconnect
        nil
      end
    end
  end
end