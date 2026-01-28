module HomeNexus
  module Network
    class Routes
      def self.apply(home_subnet)
        puts "[*] Прокладка маршрутов для подсети #{home_subnet}..."
        system("powershell -Command \"New-NetNat -Name 'VPN_NAT' -InternalIPInterfaceAddressPrefix '#{home_subnet}'\"")
      rescue
      end
    end
  end
end