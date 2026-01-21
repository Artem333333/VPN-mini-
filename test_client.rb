
require 'ruby_installer'
require 'socket'

if Gem.win_platform?
  RubyInstaller::Runtime.add_dll_directory(File.expand_path(__dir__))
end

require 'rbnacl'


shared_key = "12345678901234567890123456789012".force_encoding("BINARY") 
server_host = '127.0.0.1'
server_port = 4444

begin
  aead = RbNaCl::AEAD::ChaCha20Poly1305IETF.new(shared_key)
  nonce = RbNaCl::Random.random_bytes(12)
  message = "HELLO HOVPN! CONNECTION SUCCESSFUL".force_encoding("BINARY")

  ciphertext = aead.encrypt(nonce, message, "")
  packet = nonce + ciphertext

  socket = UDPSocket.new
  socket.send(packet, 0, server_host, server_port)

  puts "--- CLIENT SUCCESS ---"
  puts "Пакет отправлен! Кодировка BINARY применена."
rescue StandardError => e
  puts "Ошибка: #{e.message}"
end