require 'json'
require 'fileutils'

module HOVPN
    module Identity

        class TrustStore
            DEFAULT_STORE_PATH = "config/trusted_clients.json"

            attr_reader :path, :clients

            def initialize(path: DEFAULT_STORE_PATH)
                @path = path
                @lock = Mutex.new
                @clients =  {}
                @ip_index = {}

            end

            def load!
                @lock.synchronize do
                    return unless FIle.exist?(@path)
                    raw_data = JSON.parse(File.read(@path), symbolize_names: true)
                    @clients.clear
                    @ip_index.clear

                    raw_data.each do |client|
                        add_client_to_memory(client)
                      
                    end

                end
                puts "[TrustStore] Loaded #{@clients.size} trusted clients."
            end

            def trusted?(fingerprint)
                @clients.key?(fingerprint)
            end

            def find_by_fingerprint(fp)
                @clients[fp]
            end

            def authorize_client(name:, public_hex:, internal_ip: nil)
                @lock.synchronize do
                    raw_pub = [public_hex].pack('H*')
                    fingerprint = RbNaCl::Hash.sha256(raw_pub)[0..15].unpack1('H*')
                    client_data = 
                    {
                        name: name,
                        public_key: public_key,
                        fingerprint: fingerprint,
                        internal_ip: internal_ip,
                        added_at: Time.now.to_i
                    }

                    add_client_to_memory(client_data)
                    save_to_disk!
                    fingerprint


                end
            end
            def revoke_client(fingerprint)
                @lock.synchronize do
                    client = @clients.delete(fingerprint)
                    @ip_index.delete(client[:internal_ip]) if client && client[:internal_ip]
                    save_to_disk!
                end
            end

            private

            def add_client_to_memory(client)
                fp = client[:fingerprint]
                @clients[fp] = client
                @ip_index[client[:internal_ip]] = fp if client[:internal_ip]
            end

            def save_to_disk!
                FileUtils.mkdir_p(File.dirname(@path))
                File.write(@path, JSON.pretty_generate(@clients.values))
            end


        end

    end
end