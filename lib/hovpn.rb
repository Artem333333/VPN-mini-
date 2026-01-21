# frozen_string_literal: true
require 'json'
require 'yaml'
require 'fileutils'

# Исправление для async на Windows
begin
  require 'async/io'
rescue LoadError => e
  raise e unless e.message.include?('async/wrapper')
end

# Загружаем части проекта
require_relative 'crypto/keypair'
require_relative 'interface/tun_adapter'

module HOVPN
  def self.config
    @config ||= YAML.load_file('config.yml')
  end
end