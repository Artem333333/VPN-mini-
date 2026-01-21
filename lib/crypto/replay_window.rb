
module HOVPN
  module Crypto
    class ReplayWindow
      WINDOW_SIZE = 2048 

      def initialize
        @max_nonce = 0
        @window = 0 
        @lock = Mutex.new
      end


      def check?(nonce)
        @lock.synchronize do
         
          return false if nonce <= @max_nonce - WINDOW_SIZE
          
         
          return true if nonce > @max_nonce

          bit_index = @max_nonce - nonce
          (@window & (1 << bit_index)) == 0
        end
      end

      def update!(nonce)
        @lock.synchronize do
          if nonce > @max_nonce
            diff = nonce - @max_nonce
            @window = ((@window << diff) | 1) & ((1 << WINDOW_SIZE) - 1)
            @max_nonce = nonce
          else
            bit_index = @max_nonce - nonce
            @window |= (1 << bit_index)
          end
        end
      end
    end
  end
end