module HomeNexus
  module Network
    class Interface
      def self.setup
        puts "[*] Настройка сетевого интерфейса HomeNexus..."
        system("powershell -Command \"Set-NetIPInterface -InterfaceAlias 'HomeNexus' -Forwarding Enabled\"")
      end
    end
  end
end