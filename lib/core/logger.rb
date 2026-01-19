# frozen_string_literal: true

require 'logger'
require 'fileutils'
require 'json'
require 'paint' 
require 'concurrent-ruby'

module HOVPN
  module Core
    
    class Logger < ::Logger
      SEVERITY_COLORS = {
        'DEBUG' => :white,
        'INFO'  => :green,
        'WARN'  => :yellow,
        'ERROR' => :red,
        'FATAL' => [:white, :red] 
      }.freeze

      attr_accessor :context_tag, :format_mode

      def initialize(config = {})
        log_path = config[:path] || 'log/hovpn.log'
        FileUtils.mkdir_p(File.dirname(log_path))
        
        max_files = config[:max_files] || 10
        max_size  = config[:max_size]  || 10 * 1024 * 1024 

       
        super(log_path, max_files, max_size)

        @format_mode = config[:format] || :text 
        @show_colors = config[:colors] != false
        @context_tag = nil 
        
        
        @log_queue = Concurrent::Array.new
        
        setup_formatting!
      
      end

   
      def separator(char = '=', length = 60)
        info(char * length)
      
      end

      def exception(e, message = nil)
        prefix = message ? "#{message}: " : ""
        error("#{prefix}#{e.message} (#{e.class})")
        
        
        clean_trace = e.backtrace
                       .select { |line| line.include?('hovpn') || line.include?('core') }
                       .map { |line| "  => #{line.split('/').last}" }
        
        error("Traceback:\n#{clean_trace.join("\n")}") unless clean_trace.empty?
      
      end

      def sensitive(data_name, value)
        
        if value.is_a?(String) && value.length > 12
          masked = "#{value[0..5]}...#{value[-6..-1]}"
        
        else
          masked = "[REDACTED]"
        
        end
        info "Sensitive Data [#{data_name}]: #{masked}"
      
      end

     
      def progress(message)
        return unless @show_colors && $stdout.tty?
        print "\r#{Paint['[PROGRESS]', :cyan]} | #{message}          "
        $stdout.flush
      
      end

      
      def module_debug(mod_name, msg)
        return unless ENV["DEBUG_#{mod_name.upcase}"] == 'true' || level == ::Logger::DEBUG
        debug(Paint["[#{mod_name}]", :blue] + " #{msg}")
      
      end

      private

      def setup_formatting!
        self.formatter = proc do |severity, datetime, _progname, msg|
          case @format_mode
          when :json
            format_json(severity, datetime, msg)
          else
            format_text(severity, datetime, msg)
          
          end
        
        end

        
        self.class.send(:define_method, :add) do |severity, message = nil, progname = nil, &block|
          if severity >= level
            message = block.call if block
            output = formatter.call(::Logger::SEV_LABEL[severity] || 'ANY', Time.now, progname, message)
            $stdout.print output if @show_colors
          
          end
          super(severity, message, progname, &block)
        
        end
      
      end

      def format_text(severity, datetime, msg)
        time_str = datetime.strftime('%H:%M:%S')
        ctx = @context_tag ? Paint[" [#{@context_tag}]", :magenta] : ""
        
        if @show_colors
          sev_color = SEVERITY_COLORS[severity] || :white
          sev_str = Paint[severity.ljust(5), *sev_color]
          "[#{time_str}] #{sev_str}#{ctx} | #{msg}\n"
        else
          "[#{time_str}] #{severity.ljust(5)}#{ctx} | #{msg}\n"
        
        end
      
      end

      def format_json(severity, datetime, msg)
        {
          timestamp: datetime.iso8601,
          level: severity,
          context: @context_tag,
          message: msg.to_s.strip,
          pid: Process.pid
        }.to_json + "\n"
      
      end
    
    end
  
  end

end