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
      puts "=== HomeNexus запущен  ==="
      
      
      keys = Security::KeyManager.get_keys
      puts "[+] Публичный ключ: #{keys[:public]}"

      puts "[*] Включаю маршрутизацию трафика (IPv4/IPv6)..."
      system("powershell -Command \"Set-NetIPInterface -Forwarding Enabled\"")
      system("powershell -Command \"Set-NetIPInterface -AddressFamily IPv6 -Forwarding Enabled\"")
      
      Discovery::MdnsReflector.start

      puts "[ГОТОВО] Сервер работает. Порт 51820 UDP открыт."
      loop { sleep 10 }
    end
  end
end