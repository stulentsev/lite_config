require "lite_config/version"

require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/indifferent_access'

require 'yaml'

module LiteConfig
  class ImmutableError < StandardError; end
  class NotFoundError < StandardError; end

  extend self

  def fetch(name)
    name = name.to_sym
    @configs ||= {}
    @configs.key?(name) ? @configs[name] : (@configs[name] = HashWithIndifferentAccess.new(load(name)))
  end

  def config_path=(path)
    raise ImmutableError, "config_path is frozen after the first file load" unless @configs.nil?

    @config_path = path
  end

  def app_env=(app_env)
    raise ImmutableError, "app_env is frozen after the first file load" unless @configs.nil?

    @app_env = app_env
  end

  def reset
    @configs = nil
  end

  private

  def load(name)
    if File.exist?(config_filename(name))
      config = load_single(config_filename(name))
    else
      raise NotFoundError, "No config found for #{name}"
    end

    if File.exist?(local_config_filename(name))
      local_config = load_single(local_config_filename(name))

      config.deep_merge!(local_config) if local_config
    end

    config
  end

  def load_single(filename)
    hash = YAML.load_file(filename)

    has_environmenty_key?(hash) ? hash[app_env] : hash
  end

  def config_path
    @config_path ||= File.join(app_root, 'config')
  end

  def config_filename(name)
    File.join(config_path, name.to_s + '.yml')
  end

  def local_config_filename(name)
    config_filename(name).gsub(/.yml$/, '_local.yml')
  end

  def app_root
    defined?(Rails) ? Rails.root : `pwd`.strip
  end

  def app_env
    @app_env ||=
    if defined?(Rails)
      Rails.env
    elsif ENV['RAILS_ENV']
      ENV['RAILS_ENV']
    elsif ENV['RACK_ENV']
      ENV['RACK_ENV']
    else
      'development'
    end
  end

  def has_environmenty_key?(hash)
    %w(development test production).any?{ |envy| hash.key?(envy) } if hash
  end
end

def LiteConfig(name)
  LiteConfig.fetch(name)
end
