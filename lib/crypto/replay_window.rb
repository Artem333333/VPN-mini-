module HOVPN
  module Crypto

    
    class ReplayWindow
      WINDOW_SIZE = 256
      MAX_NONCE   = (1 << 63) - 1

      attr_reader :max_nonce,
                  :dropped_count,
                  :replay_count,
                  :too_old_count,
                  :invalid_count

      def initialize
        @lock = Mutex.new
        reset!
      end

      
      def check?(nonce)
        return reject!(:invalid) if nonce.nil? || nonce <= 0 || nonce > MAX_NONCE

        @lock.synchronize do
          
          if nonce <= @max_nonce - WINDOW_SIZE
            return reject!(:too_old)
          end

          
          return true if nonce > @max_nonce

         
          bit_index = @max_nonce - nonce
          mask = 1 << bit_index

          if (@window & mask) != 0
            return reject!(:replay)
          end

          true
        end
      end

      
      def update!(nonce)
        @lock.synchronize do
          if nonce > @max_nonce
            diff = nonce - @max_nonce

            if diff >= WINDOW_SIZE
              @window = 1
            else
              @window = (@window << diff) | 1
            end

            @max_nonce = nonce
          else
            bit_index = @max_nonce - nonce
            @window |= (1 << bit_index)
          end
        end
      end

     
      def packet_loss_ratio
        @lock.synchronize do
          return 0.0 if @max_nonce == 0

          set_bits = @window.to_s(2).count('1')
          expected = [WINDOW_SIZE, @max_nonce].min
          1.0 - (set_bits.to_f / expected)
        end
      end

     
      def stats
        @lock.synchronize do
          {
            max_nonce:      @max_nonce,
            dropped_total:  @dropped_count,
            replay:         @replay_count,
            too_old:        @too_old_count,
            invalid:        @invalid_count,
            loss_ratio:     packet_loss_ratio
          }
        end
      end

      
      def reset!
        @lock.synchronize do
          @max_nonce      = 0
          @window         = 0
          @dropped_count  = 0
          @replay_count   = 0
          @too_old_count  = 0
          @invalid_count  = 0
        end
      end

      private

      def reject!(reason)
        @dropped_count += 1

        case reason
        when :replay   then @replay_count  += 1
        when :too_old  then @too_old_count += 1
        when :invalid  then @invalid_count += 1
        end

        false
      end
    end

  end
end
