module HOVPN
  module Core
    class Error < StandardError; end
    class ConfigError < Error; end
    class NetworkError < Error; end
    class CryptoError < Error; end
    class SessionError < Error; end
  end
end
