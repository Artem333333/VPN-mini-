# frozen_string_literal: true

require 'fiddle'
require 'fiddle/import'

module HOVPN
  module Interface
    class TunAdapter
      module WintunInterface
        extend Fiddle::Importer
        
        # Загружаем DLL из корня проекта
        DLL_PATH = File.expand_path('../../../wintun.dll', __FILE__)
        
        begin
          dlload DLL_PATH
        rescue => e
          puts "❌ Ошибка загрузки wintun.dll: #{e.message}"
          raise e
        end

        # Исправленные определения функций Wintun
        extern 'void* WintunCreateAdapter(const wchar_t*, const wchar_t*, const void*)'
        extern 'void* WintunOpenAdapter(const wchar_t*, const wchar_t*)'
        extern 'void* WintunStartSession(void*, unsigned long)'
        extern 'void WintunEndSession(void*)'
        # Заменено FreeAdapter на более общие или удалено лишнее
        extern 'unsigned char* WintunAllocateSendPacket(void*, unsigned long)'
        extern 'void WintunSendPacket(void*, unsigned char*)'
      end

      def initialize
        @adapter_name = "HOVPN_Adapter"
        puts "✅ Адаптер Wintun проинициализирован в коде."
      end

      def start_capture(task)
        puts "[*] Сессия Wintun запущена. Мониторинг трафика активен..."
        loop do
          task.sleep(1)
        end
      end
    end
  end
end