
module HOVPN
  module Network

    class Packet
      MAGIC = "HO"
      
      TYPES = {
        handshake_init: 0x01,
        handshake_resp: 0x02,
        transport_data: 0x03,
        keeplive:       0x04,
        disconnect:     0x05
      }.freeze

      
      MIN_SIZE = 7

      attr_reader :type, :session_id, :payload

      def initialize(type:, session_id:, payload:)
        @type = type
        @session_id = session_id
        @payload = payload || ""
      end

      
      def to_binary
        return nil unless valid?
        
        [
          MAGIC,
          TYPES[@type] || 0x00,
          @session_id,
          @payload
        ].pack("a2 C L> a*") 
      end

     
      def self.from_binary(raw_data)
        return nil if raw_data.nil? || raw_data.bytesize < MIN_SIZE

       
        magic, type_id, session_id, payload = raw_data.unpack("a2 C L> a*")

 
        return nil unless magic == MAGIC
        
        type_name = TYPES.key(type_id)
        return nil unless type_name

        new(
          type: type_name,
          session_id: session_id,
          payload: payload
        )
      rescue StandardError => e
        puts "[Packet] Corrupt data received: #{e.message}"
        nil
      end

      def valid?
        !@payload.nil? && @payload.bytesize <= 1450 && TYPES.key?(@type)
      end

      def inspect
        "<Packet type=#{@type} sid=#{@session_id} size=#{@payload.bytesize}b>"
      end
    end
  end
end