# frozen_string_literal: true
module HOVPN
  module Crypto
    class KeyPair
      def self.ensure_exists!(path)
        return if File.exist?(path)
        
        puts "[+] Ключи не найдены. Генерируем новую пару..."
        private_key = RbNaCl::PrivateKey.generate
        FileUtils.mkdir_p(File.dirname(path))
        
        File.write(path, private_key.to_bytes.unpack1('H*'))
        File.write("#{path}.pub", private_key.public_key.to_bytes.unpack1('H*'))
        puts "✅ Ключи созданы и сохранены в #{path}"
      end
    end
  end
end