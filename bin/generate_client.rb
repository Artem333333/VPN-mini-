require 'yaml'
require_relative '../lib/security/keys'

puts "=== Генератор клиента HomeNexus ==="

config_path = File.expand_path(File.join(__dir__, '..', 'config', 'settings.yml'))
config = YAML.load_file(config_path)

client_keys = HomeNexus::Security::KeyManager.get_keys
server_pub_key = "SvDjWMoQmsHb6H+iQSdKMwpycjLuYatIxNcsgDWvWlg=" 
external_ip = `curl -s ifconfig.me`.strip
external_ip = "ТВОЙ_ВНЕШНИЙ_IP" if external_ip.empty?

client_config = <<~CONF
  [Interface]
  PrivateKey = #{client_keys[:private]}
  Address = 10.0.0.2/32, fd00::2/128
  DNS = 1.1.1.1

  [Peer]
  PublicKey = #{server_pub_key}
  Endpoint = #{external_ip}:51820
  AllowedIPs = 0.0.0.0/0, ::/0
  PersistentKeepalive = 25
CONF

file_name = "client_home.conf"
File.write(file_name, client_config)

puts "[ГОТОВО] Файл конфигурации создан: #{file_name}"
puts "[*] Твой внешний IP определен как: #{external_ip}"
