module HomeNexus
  module Security
    class KeyManager
      def self.get_keys
        {
          private: ENV['PRIVATE_KEY'],
          public:  ENV['PUBLIC_KEY']
        }
      end
    end
  end
end
