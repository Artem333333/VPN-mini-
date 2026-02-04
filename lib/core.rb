require 'dotenv/load'
require 'yaml'
require 'security/keys'
require 'network/nat_pmp'
require 'discovery/mdns_reflector'

module HomeNexus
  class App
    def initialize
      config_path = File.expand_path('../config/settings.yml', __dir__)
      @config = YAML.load_file(config_path)
    end

    def run
      puts "=== HomeNexus ==="
      
      keys = Security::KeyManager.get_keys
      puts "[+] Public key server: #{keys[:public]}"

      puts "[*] Configuring system forwarding (IPv4/IPv6)..."
      system("powershell -Command \"Set-NetIPInterface -Forwarding Enabled\"")
      system("powershell -Command \"Set-NetIPInterface -AddressFamily IPv6 -Forwarding Enabled\"")
      
      setup_tailscale

      Discovery::MdnsReflector.start

      Network::NatPmp.open_port(@config['network']['listen_port'])

      puts "[ГОТОВО] Server is active. Exit point: Local network."
      puts "[*] Waiting for connections..."
      loop { sleep 10 }
    end

    private

    def setup_tailscale
      puts "[*] Integration with Tailscale (NAT Traversal)..."
      routes = @config['network']['home_subnet']
      ts_cmd = "tailscale up --advertise-exit-node --advertise-routes=#{routes} --accept-routes"
      
      if system(ts_cmd)
        puts "[+] Tailscale has been successfully configured as an Exit Node."
        ts_ip = `tailscale ip -4`.strip
        puts "[+] Your address on the Tailscale network: #{ts_ip}"
      else
        puts "[!] Error: Make sure Tailscale is installed and running."
      end
    end
  end
end