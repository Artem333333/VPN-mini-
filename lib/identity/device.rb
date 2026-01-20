
require_relative '../network/udp'
require_relative '../network/stun'
require_relative '../network/nat_traversal'

def initialize_resources!
        
        @keystore.load_or_generate! unless @keystore.unlocked?
        @trust_store.load!

        
        begin
         
          port = @metadata[:config]&.fetch(:listen_port, 51820) || 51820
          
         
          raw_udp = HOVPN::Network::UDP.new(port: port)
          @network_driver = HOVPN::Network::SocketWrapper.new(raw_udp)
          
          @stun_client = HOVPN::Network::STUN.new(@network_driver)
          @nat_manager = HOVPN::Network::NATTraversal.new(@network_driver)
          
          puts "[Device] Network stack online on port #{port}"
        rescue Errno::EADDRINUSE
          raise "Critical Error: Port #{port} already in use. Is another HOVPN instance running?"
        end

       
        puts "[Device] Contacting STUN servers to bypass NAT..."
        @public_address = @stun_client.resolve_public_address
        
        if @public_address
          
          @metadata[:public_endpoint] = "#{@public_address[:ip]}:#{@public_address[:port]}"
          puts "[Device] Discovery Success: Remote peers should connect to #{@metadata[:public_endpoint]}"
        else
          @metadata[:public_endpoint] = nil
          puts "[Device] Warning: Running in 'Shadow Mode' (NAT not pierced). Relay might be required."
        end
      end