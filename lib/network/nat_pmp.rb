require 'socket'

module HomeNexus
  module Network
    class NatPmp
      def self.open_port(port)
        puts "[*] Пробивка NAT (UPnP/NAT-PMP)..."
  
        begin
          socket = UDPSocket.new
         
          system("powershell -Command \"$com = New-Object -ComObject HNetCfg.NATUPnP; $mappings = $com.StaticPortMappingCollection; $mappings.Add(#{port}, 'UDP', #{port}, '127.0.0.1', $true, 'HomeNexus VPN')\"")
          puts "[+] Порт #{port} проброшен на роутере."
        rescue
          puts "[!] Не удалось пробросить порт автоматически."
        end
      end
    end
  end
end