require 'json'
require 'fileutils'
require 'tempfile'
require 'digest'

module HOVPN
  module Identity
    
    class KeyStore
      DEFAULT_KEY_PATH = "config/server.key"
      BACKUP_SUFFIX    = ".bak"
      
      attr_reader :path, :last_loaded_at, :key_pair

      def initialize(path: DEFAULT_KEY_PATH, password: nil)
        @path     = path
        @password = password || "default_dev_pass" 
        @key_pair = nil
        @lock     = Mutex.new 
        @last_loaded_at = nil
      end

      
      def unlocked?
        !@key_pair.nil?
      end

      def key
        @key_pair
      end

      def wipe_from_memory!
        @lock.synchronize do
          @key_pair = nil
          @password = nil
          puts "[KeyStore] Sensitive data wiped from RAM."
        end
      end

      def integrity_ok?
        return false unless File.exist?(@path)
        !!JSON.parse(File.read(@path)) rescue false
      end

      def public_identity
        pub_path = "#{@path}.pub"
        
        if File.exist?(pub_path)
          JSON.parse(File.read(pub_path), symbolize_names: true)
        elsif unlocked?
          id = {
            fingerprint: @key_pair.respond_to?(:fingerprint) ? @key_pair.fingerprint : "F1:N6:E1:R2:STUB",
            public_key:  @key_pair.respond_to?(:public_hex) ? @key_pair.public_hex : "0xPUB_STUB",
            created_at:  Time.now.to_i,
            version:     "1.0"
          }
          File.write(pub_path, id.to_json)
          id
        else
          raise "Keystore locked and no public identity file found"
        end
      end

      def load_or_generate!
        @lock.synchronize do
          if File.exist?(@path)
            
            puts "[KeyStore] Loading existing key from #{@path}..."
            @key_pair = Struct.new(:fingerprint, :public_hex).new("DEV-FINGERPRINT-#{rand(100)}", "0x#{SecureRandom.hex(8)}")
          else
            puts "[KeyStore] Generating new identity key pair..."
            generate_and_lock!
          end
          @last_loaded_at = Time.now
          public_identity 
        end
      end

      private

      def generate_and_lock!
        
        @key_pair = Struct.new(:fingerprint, :public_hex).new("GEN-#{SecureRandom.hex(4)}", "0x#{SecureRandom.hex(12)}")
       
      end

      def enforce_permissions!
        File.chmod(0600, @path) if File.exist?(@path)
      end

      def save!(password = @password)
        raise "Password required" if password.nil? || password.empty?
        dir = File.dirname(@path)
        FileUtils.mkdir_p(dir)

        Tempfile.create(['hovpn_key', '.tmp'], dir) do |tmp|
          tmp.chmod(0600) 
          
          File.write(tmp.path, {key: "encrypted_data_stub"}.to_json)
          File.rename(tmp.path, @path)
        end
        enforce_permissions!
      end
    end
  end
end