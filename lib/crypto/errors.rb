
module HOVPN
  module Core
    module Errors
      class HOVPNError < StandardError; end
      class CryptoError < HOVPNError; end
      class NetworkError < HOVPNError; end
      class ConfigurationError < HOVPNError; end
    end
  end
end