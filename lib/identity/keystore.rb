
require 'json'
require 'fileutils'
require 'tempfile'
require 'digest'

module HOVPN
  module Identity
    class Keystore
      DEFAULT_KEY_PATH = "config/server.key"
      BACKUP_SUFFIX    = ".bak"
      
      attr_reader :path, :last_loaded_at

      def initialize(path: DEFAULT_KEY_PATH, password: nil)
        @path     = path
        @password = password
        @key_pair = nil
        @lock     = Mutex.new 
        @last_loaded_at = nil
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
            fingerprint: @key_pair.fingerprint,
            public_key:  @key_pair.public_hex,
            created_at:  @key_pair.created_at.to_i,
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
            load_key!
          else
            generate_and_lock!
          end
         
          public_identity 
        end
      end


      private

    
      def enforce_permissions!
        File.chmod(0600, @path) if File.exist?(@path)
      end

      def save!(password = @password)
        raise "Password required" if password.nil? || password.empty?
        
        dir = File.dirname(@path)
        FileUtils.mkdir_p(dir)

        Tempfile.create(['hovpn_key', '.tmp'], dir) do |tmp|
          tmp.chmod(0600) 
          @key_pair.save_encrypted!(tmp.path, password)
          
          File.rename(tmp.path, @path)
        end
        enforce_permissions!
      end
    end
  end
end