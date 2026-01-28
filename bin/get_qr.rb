require 'rqrcode'

SERVER_PUB_KEY = "+av5NUtFak8fO5xtV9r2rNNCgfeQdYYAeX3hu2iJ5R4="

puts "[*] Определяю внешний адрес твоего роутера..."
ext_ip = `curl -s ifconfig.me`.strip
ext_ip = "ВВЕДИ_СВОЙ_ВНЕШНИЙ_IP_ВРУЧНУЮ" if ext_ip.empty?

puts "[*] Генерирую ключи для смартфона..."
client_priv = `wg genkey`.strip
client_pub  = `echo #{client_priv} | wg pubkey`.strip

config = <<~CONF
[Interface]
PrivateKey = #{client_priv}
Address = 10.0.0.2/32, fd00::2/128
DNS = 1.1.1.1

[Peer]
PublicKey = #{SERVER_PUB_KEY}
Endpoint = #{ext_ip}:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
CONF


puts "\n--- ОТСКАНЕРУЙ ЭТО В ПРИЛОЖЕНИИ WIREGUARD ---\n\n"
qr = RQRCode::QRCode.new(config)
puts qr.as_ansi(light: "\033[47m", dark: "\033[40m", fill_character: "  ", quiet_zone_size: 2)
puts "\n--------------------------------------------"
puts "Внешний IP: #{ext_ip}"
puts "Публичный ключ телефона: #{client_pub}"