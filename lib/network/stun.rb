require 'securerandom'
require 'timeout'

module HOVPN
  module Network
    class STUN
      SERVERS = [
        ['stun.l.google.com', 19302],
        ['stun1.l.google.com', 19302],
        ['stun.cloudflare.com', 3478]
      ].freeze

      
      MAGIC_COOKIE = 0x2112A442
      ATTR_MAPPED_ADDRESS = 0x0001
      ATTR_XOR_MAPPED_ADDRESS = 0x0020

      def initialize(udp_driver)
        @driver = udp_driver
      end

      def resolve_public_address
        SERVERS.each do |host, port|
          begin
            result = request_address(host, port)
            return result if result
          rescue StandardError => e
            puts "[STUN] Server #{host} failed: #{e.message}"
            next
          end
        end
        nil
      end

      private

      def request_address(host, port)
        transaction_id = SecureRandom.random_bytes(12)
    
        header = [0x0001, 0x0000, MAGIC_COOKIE].pack("n n N") + transaction_id
        
        @driver.send(header, host, port)

        Timeout.timeout(2) do
          
          loop do
            response, addr = @driver.recv
            next unless response && response.bytesize >= 20
            
            
            next unless response[8, 12] == transaction_id
            
            return parse_response(response)
          end
        end
      rescue Timeout::Error, StandardError
        nil
      end

      def parse_response(data)
        pos = 20 
        
        while pos + 4 <= data.bytesize
          attr_type, attr_len = data[pos, 4].unpack("n n")
          
          case attr_type
          when ATTR_XOR_MAPPED_ADDRESS
            
            xor_port = data[pos + 6, 2].unpack1("n")
            port = xor_port ^ (MAGIC_COOKIE >> 16)

            xor_ip = data[pos + 8, 4].unpack1("N")
            ip_int = xor_ip ^ MAGIC_COOKIE
            ip = [ip_int].pack("N").unpack("C4").join('.')
            return { ip: ip, port: port, type: :xor_mapped }

          when ATTR_MAPPED_ADDRESS
           
            port = data[pos + 6, 2].unpack1("n")
            ip = data[pos + 8, 4].unpack("C4").join('.')
            return { ip: ip, port: port, type: :mapped }
          end
          
          
          pos += 4 + ((attr_len + 3) & ~3)
        end
        nil
      end
    end
  end
end